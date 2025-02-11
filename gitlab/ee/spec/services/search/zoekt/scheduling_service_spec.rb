# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::SchedulingService, :clean_gitlab_redis_shared_state, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(task.to_s) }
  let_it_be_with_reload(:node) { create(:zoekt_node, :enough_free_space) }

  subject(:execute_task) { service.execute }

  before do
    allow(described_class).to receive(:logger).and_return(logger)
  end

  shared_examples 'a execute_every task' do |opts = {}|
    let(:redis_spy) { instance_spy(Redis) }
    let(:period) { opts[:period] }

    it 'uses cache when given a cache period', :clean_gitlab_redis_shared_state do
      allow(Gitlab::Redis::SharedState).to receive(:with).and_yield(redis_spy)
      service.execute

      if period.present?
        expect(redis_spy).to have_received(:set).with(service.cache_key, 1, ex: period, nx: true)
      else
        expect(redis_spy).not_to have_received(:set).with(service.cache_key, anything, anything)
      end
    end

    context 'when on development environment', :clean_gitlab_redis_shared_state do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'does not use cache' do
        expect(Gitlab::Redis::SharedState).not_to receive(:with)
      end
    end
  end

  describe 'TASKS' do
    it 'includes the keys from CONFIG' do
      described_class::CONFIG.each_key do |key|
        expect(described_class::TASKS.include?(key)).to be_truthy
      end
    end

    described_class::CONFIG.each do |key, opts|
      context "with proper cache period for dispatch task '#{key}'" do
        let(:task) { key }

        it_behaves_like 'a execute_every task', period: opts[:period]
      end
    end
  end

  describe '.execute' do
    let(:task) { :foo }

    it 'executes the task' do
      expect(described_class).to receive(:new).with(task).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(task)
    end

    context 'when passed without_cache argument' do
      let(:redis) { instance_double(Redis) }

      it 'removes the cache key before executing the task' do
        expect(Gitlab::Redis::SharedState).to receive(:with).and_yield(redis)
        expect(redis).to receive(:del).with(service.cache_key)

        expect(described_class).to receive(:new).with(task).and_return(service)
        expect(service).to receive(:execute)

        described_class.execute(task, without_cache: true)
      end
    end
  end

  describe '.execute!' do
    let(:task) { :foo }

    it 'calls .execute specifying without_cache' do
      expect(described_class).to receive(:execute).with(task, without_cache: true)

      described_class.execute!(task)
    end
  end

  describe '#execute' do
    let(:task) { :foo }

    it 'raises an exception when unknown task is provided' do
      expect { service.execute }.to raise_error(ArgumentError)
    end

    it 'raises an exception when the task is not implemented' do
      stub_const('::Search::Zoekt::SchedulingService::TASKS', [:foo])

      expect { service.execute }.to raise_error(NotImplementedError)
    end

    it 'converts string task to symbol' do
      expect(described_class.new(task.to_s).task).to eq(task.to_sym)
    end
  end

  describe '#cache_key' do
    context 'with tasks that have empty cache periods' do
      it 'is formatted correctly based on task name' do
        %i[foo bar baz].each do |task|
          expect(described_class.new(task).cache_key).to eq("search/zoekt/scheduling_service:execute_every:-:#{task}")
        end
      end
    end

    context 'with tasks that have cache periods configured' do
      it 'is formatted correctly based on task name and cache period' do
        %i[adjust_indices_reserved_storage_bytes lost_nodes_check update_replica_states].each do |task|
          svc = described_class.new(task)
          expect(svc.cache_key).to eq("search/zoekt/scheduling_service:execute_every:#{svc.cache_period}:#{task}")
        end
      end
    end
  end

  describe '#cache_period' do
    context 'with a task from CONFIG' do
      it 'returns the period when configured' do
        expect(described_class.new(:adjust_indices_reserved_storage_bytes).cache_period).to eq(10.minutes)
        expect(described_class.new(:update_replica_states).cache_period).to eq(2.minutes)
      end

      it 'returns nil when not configured' do
        expect(described_class.new(:mark_indices_as_ready).cache_period).to be_nil
      end
    end

    context 'with a task not from CONFIG' do
      it 'returns nil' do
        expect(described_class.new(:foo).cache_period).to be_nil
      end
    end
  end

  describe '#eviction' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:task) { :eviction }

    before do
      allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
    end

    it 'returns false unless saas' do
      expect(execute_task).to be(false)
    end

    context 'when on .com', :saas do
      let_it_be(:zoekt_index) { create(:zoekt_index, node: node) }

      context 'when nodes have enough storage' do
        it 'returns false' do
          expect(logger).not_to receive(:info)
          expect { execute_task }.not_to change { Search::Zoekt::Replica.count }
        end
      end

      context 'when nodes are over the watermark high limit' do
        let_it_be(:node_out_of_storage) { create(:zoekt_node, :not_enough_free_space) }
        let_it_be(:namespace_statistics) do
          create(:namespace_root_storage_statistics, repository_size: node_out_of_storage.used_bytes * 0.7)
        end

        let_it_be(:ns) { create(:group, root_storage_statistics: namespace_statistics) }
        let_it_be(:enabled_ns) { create(:zoekt_enabled_namespace, namespace: ns) }
        let_it_be(:zoekt_index2) do
          create(:zoekt_index, node: node_out_of_storage,
            zoekt_enabled_namespace: enabled_ns,
            used_storage_bytes: node_out_of_storage.used_bytes)
        end

        it 'removes extra indices and logs' do
          expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task,
            'message' => 'Detected nodes over watermark',
            'watermark_limit_high' => ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH,
            'count' => 1 }
          )

          expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task,
            'message' => 'Unassigning namespaces from node',
            'watermark_limit_high' => ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH,
            'count' => 1,
            'node_used_bytes' => 90000000,
            'node_expected_used_bytes' => 27000001,
            'total_repository_size' => namespace_statistics.repository_size,
            'meta' => node_out_of_storage.metadata_json.merge(
              'zoekt.used_bytes' => 27000001, 'zoekt.storage_percent_used' => 0.27000001) }
          )

          expect { execute_task }.to change { Search::Zoekt::Replica.count }.from(2).to(1)
          expect(enabled_ns.reload.metadata['last_used_storage_bytes']).to eq(node_out_of_storage.used_bytes)
        end

        it 'keeps search enabled for the enabled namespace' do
          allow(logger).to receive(:info)
          expect { execute_task }.not_to change { zoekt_index2.zoekt_enabled_namespace.reload.search }
        end
      end
    end
  end

  describe '#remove_expired_subscriptions' do
    let(:task) { :remove_expired_subscriptions }

    it 'returns false unless saas' do
      expect(execute_task).to be(false)
    end

    context 'when on .com', :saas do
      let_it_be(:expiration_date) { Time.zone.today - Search::Zoekt::EXPIRED_SUBSCRIPTION_GRACE_PERIOD }
      let_it_be(:zkt_enabled_namespace) { create(:zoekt_enabled_namespace) }
      let_it_be(:zkt_enabled_namespace2) { create(:zoekt_enabled_namespace) }
      let_it_be(:subscription) { create(:gitlab_subscription, namespace: zkt_enabled_namespace2.namespace) }
      let_it_be(:expired_subscription) do
        create(:gitlab_subscription, namespace: zkt_enabled_namespace.namespace, end_date: expiration_date - 1.day)
      end

      it 'destroys zoekt_namespaces with expired subscriptions' do
        expect { execute_task }.to change { ::Search::Zoekt::EnabledNamespace.count }.by(-1)

        expect(::Search::Zoekt::EnabledNamespace.pluck(:id)).to contain_exactly(zkt_enabled_namespace2.id)
      end
    end
  end

  describe '#node_assignment' do
    let(:task) { :node_assignment }

    let_it_be(:namespace) { create(:group) }
    let_it_be_with_reload(:namespace_statistics) { create(:namespace_root_storage_statistics, repository_size: 1000) }
    let_it_be_with_reload(:namespace_with_statistics) do
      create(:group, :with_hierarchy, root_storage_statistics: namespace_statistics, children: 1, depth: 3)
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(zoekt_node_assignment: false)
      end

      it 'returns false' do
        expect(execute_task).to be(false)
      end
    end

    context 'when some zoekt enabled namespaces missing zoekt index' do
      let(:logger) { instance_double(::Search::Zoekt::Logger) }
      let_it_be(:zkt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace.root_ancestor) }
      let_it_be(:zkt_enabled_namespace2) do
        create(:zoekt_enabled_namespace, namespace: namespace_with_statistics.root_ancestor)
      end

      let_it_be(:zoekt_replica) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: zkt_enabled_namespace2) }

      before do
        allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
      end

      context 'when there are no online nodes' do
        before do
          allow(Search::Zoekt::Node).to receive(:online).and_return(Search::Zoekt::Node.none)
        end

        it 'returns false and does nothing' do
          expect(execute_task).to be(false)
          expect(Search::Zoekt::EnabledNamespace).not_to receive(:with_missing_indices)
        end
      end

      context 'when there is not enough space in any nodes' do
        before do
          node.update_column(:total_bytes, 100)
        end

        it 'does not creates a record of Search::Zoekt::Index for the namespace' do
          node_free_space = node.total_bytes - node.used_bytes
          expect(namespace_statistics.repository_size).to be > node_free_space
          expect(zkt_enabled_namespace.indices).to be_empty
          expect(zkt_enabled_namespace2.indices).to be_empty
          expect(Search::Zoekt::Node).to receive(:online).and_call_original
          expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                          'message' => "RootStorageStatistics isn't available",
                                                          'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
          )
          expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                          'message' => 'Namespace is too big even for multiple indices',
                                                          'zoekt_enabled_namespace_id' => zkt_enabled_namespace2.id })
          expect { execute_task }.not_to change { Search::Zoekt::Index.count }
          expect(zkt_enabled_namespace.indices).to be_empty
          expect(zkt_enabled_namespace2.indices).to be_empty
        end

        context 'when there is space for the repository but not for the WATERMARK_LIMIT_LOW' do
          before do
            node.update_column(:total_bytes,
              (namespace_statistics.repository_size * described_class::BUFFER_FACTOR) + node.used_bytes)
          end

          it 'does not creates a record of Search::Zoekt::Index for the namespace' do
            node_free_space = node.total_bytes - node.used_bytes
            # Assert that node's free space is equal to the repository_size times BUFFER_FACTOR
            expect(namespace_statistics.repository_size * described_class::BUFFER_FACTOR).to eq node_free_space
            expect(zkt_enabled_namespace.indices).to be_empty
            expect(zkt_enabled_namespace2.indices).to be_empty
            expect(Search::Zoekt::Node).to receive(:online).and_call_original
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                    'message' => "RootStorageStatistics isn't available",
                                                    'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                    'message' => 'Namespace is too big even for multiple indices',
                                                    'zoekt_enabled_namespace_id' => zkt_enabled_namespace2.id }
            )
            expect { execute_task }.not_to change { Search::Zoekt::Index.count }
            expect(zkt_enabled_namespace.indices).to be_empty
            expect(zkt_enabled_namespace2.indices).to be_empty
          end
        end
      end

      context 'when there is enough space in the node' do
        context 'when a new record of Search::Zoekt::Index could not be saved' do
          it 'logs error' do
            expect(zkt_enabled_namespace.indices).to be_empty
            expect(zkt_enabled_namespace2.indices).to be_empty
            expect(Search::Zoekt::Node).to receive(:online).and_call_original
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                    'message' => "RootStorageStatistics isn't available",
                                                    'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )
            allow_next_instance_of(Search::Zoekt::Index) do |instance|
              allow(instance).to receive(:valid?).and_return(false)
            end
            expect(logger).to receive(:error).with(hash_including('zoekt_index', 'class' => described_class.to_s,
              'task' => task, 'message' => 'Could not save Search::Zoekt::Index'))
            expect { execute_task }.not_to change { Search::Zoekt::Index.count }
            expect(zkt_enabled_namespace.indices).to be_empty
            expect(zkt_enabled_namespace2.indices).to be_empty
          end
        end

        it 'creates a record of Search::Zoekt::Index with state pending for the namespace which has statistics' do
          expect(zkt_enabled_namespace.indices).to be_empty
          expect(zkt_enabled_namespace2.indices).to be_empty
          expect(Search::Zoekt::Node).to receive(:online).and_call_original
          expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                  'message' => "RootStorageStatistics isn't available",
                                                  'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
          )
          expect { execute_task }.to change { Search::Zoekt::Index.count }.by(1)
          expect(zkt_enabled_namespace.indices).to be_empty
          index = zkt_enabled_namespace2.indices.last
          expect(index).not_to be_nil
          expect(index.namespace_id).to eq zkt_enabled_namespace2.root_namespace_id
          expect(index.reserved_storage_bytes).not_to be_nil
          expect(index).to be_pending
        end

        context 'when storage_size for a namespace is 0' do
          before do
            namespace_statistics.update_column(:repository_size, 0)
          end

          it 'creates a record of Search::Zoekt::Index with state ready for the namespace which has statistics' do
            expect(zkt_enabled_namespace.indices).to be_empty
            expect(zkt_enabled_namespace2.indices).to be_empty
            expect(Search::Zoekt::Node).to receive(:online).and_call_original
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                     'message' => "RootStorageStatistics isn't available",
                                                     'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )
            expect { execute_task }.to change { Search::Zoekt::Index.count }.by(1)
            expect(zkt_enabled_namespace.indices).to be_empty
            index = zkt_enabled_namespace2.indices.last
            expect(index).not_to be_nil
            expect(index.namespace_id).to eq zkt_enabled_namespace2.root_namespace_id
            expect(index.reserved_storage_bytes).not_to be_nil
            expect(index).to be_ready
          end
        end

        it 'assigns the index to a replica' do
          expect(zkt_enabled_namespace.indices).to be_empty
          expect(zkt_enabled_namespace2.indices).to be_empty
          expect(Search::Zoekt::Node).to receive(:online).and_call_original
          expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                  'message' => "RootStorageStatistics isn't available",
                                                  'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
          )
          expect { execute_task }.to change { Search::Zoekt::Index.count }.by(1)
          expect(zkt_enabled_namespace.indices).to be_empty
          execute_task

          index = zkt_enabled_namespace2.indices.last
          expect(index.replica).to be_present
        end
      end

      context 'for a big namespace when it can not be accommodated in a single node' do
        let_it_be(:project) { create(:project, :repository, namespace: namespace_with_statistics) }
        let_it_be(:project2) { create(:project, :repository, namespace: namespace_with_statistics.children.first) }
        let_it_be_with_reload(:project_stat1) { create(:project_statistics, project: project, with_data: true) }
        let_it_be_with_reload(:project_stat2) do
          create(:project_statistics, project: project2, with_data: true, size_multiplier: 18)
        end

        before do
          node.update_column(:total_bytes, 100)
        end

        context 'when all projects repository_size is 0' do
          before do
            ProjectStatistics.where(id: [project_stat1.id, project_stat2.id]).update_all(repository_size: 0)
          end

          it 'creates single index in ready state' do
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                     'message' => "RootStorageStatistics isn't available",
                                                     'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )
            expect { execute_task }.to change { Search::Zoekt::Index.count }.by(1)
            indices = zkt_enabled_namespace2.indices
            expect(indices.count).to eq 1
            expect(indices.first.metadata['project_id_from']).to eq namespace_with_statistics.all_projects.first.id
            expect(indices.first).to be_ready
          end
        end

        context 'when a namespace can be accommodated within 5 nodes' do
          before do
            create_list(:zoekt_node, 4)
          end

          it 'creates multiple indices in pending state' do
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                     'message' => "RootStorageStatistics isn't available",
                                                     'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )

            expect { execute_task }.to change { Search::Zoekt::Index.count }.by(2)
            indices = zkt_enabled_namespace2.indices
            expect(indices.count).to eq 2
            expect(indices.first.metadata['project_id_from']).to eq namespace_with_statistics.all_projects.first.id
            expect(indices.first.metadata['project_id_to']).to eq namespace_with_statistics.all_projects.first.id
            expect(indices.last.metadata['project_id_from']).to eq namespace_with_statistics.all_projects.last.id
            expect(indices.first).to be_pending
            expect(indices.last).to be_pending
          end
        end

        context 'when a namespace can not be accommodated within 5 nodes' do
          before do
            project_stat1.update_column(:repository_size, 100)
            project_stat2.update_column(:repository_size, 100)
          end

          it 'does not create any indices and log error' do
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                     'message' => "RootStorageStatistics isn't available",
                                                     'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )

            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                     'message' => 'Namespace is too big even for multiple indices',
                                                     'zoekt_enabled_namespace_id' => zkt_enabled_namespace2.id }
            )
            expect { execute_task }.not_to change { Search::Zoekt::Index.count }
          end
        end
      end
    end
  end

  describe '#mark_indices_as_ready' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:task) { :mark_indices_as_ready }

    before do
      create(:zoekt_index, :ready)
      create(:zoekt_index, state: :pending)
      create(:zoekt_index, state: :in_progress)
      create(:zoekt_index, state: :reallocating)
      create(:zoekt_index, state: :orphaned)
      create(:zoekt_index, state: :pending_deletion)
    end

    context 'when there are no initializing indices' do
      before do
        allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
      end

      it 'does not publish any event' do
        expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task,
                                                'message' => 'Condition not met' })
        expect { execute_task }.not_to publish_event(Search::Zoekt::IndexMarkedAsReadyEvent)
      end
    end

    context 'when there are initializing indices' do
      before do
        create(:zoekt_index, state: :initializing)
      end

      it 'publishes Search::Zoekt::IndexMarkedAsReadyEvent event' do
        expect { execute_task }.to publish_event(Search::Zoekt::IndexMarkedAsReadyEvent).with(Hash.new({}))
      end
    end
  end

  describe '#initial_indexing' do
    let(:task) { :initial_indexing }
    let_it_be_with_reload(:index) { create(:zoekt_index, state: :pending) }

    context 'when there are no zoekt_indices in pending state' do
      before do
        Search::Zoekt::Index.update_all(state: :initializing)
      end

      it 'does not publish the event Search::Zoekt::InitialIndexingEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::InitialIndexingEvent)
      end
    end

    it 'publishes the event Search::Zoekt::InitialIndexingEvent for the pending indices' do
      expect { execute_task }.to publish_event(Search::Zoekt::InitialIndexingEvent).with({ index_id: index.id })
    end
  end

  describe '#auto_index_self_managed' do
    let(:task) { :auto_index_self_managed }
    let_it_be(:sub_group) { create(:group, :nested) }
    let_it_be(:top_group) { create(:group) }
    let_it_be(:top_group2) { create(:group) }

    before do
      stub_ee_application_setting(zoekt_auto_index_root_namespace: true)
      create(:zoekt_enabled_namespace, root_namespace_id: top_group2.id)
    end

    context 'for gitlab.com', :saas do
      it 'does not create any record of Search::Zoekt::EnabledNamespace' do
        expect { execute_task }.not_to change { Search::Zoekt::EnabledNamespace.count }
      end
    end

    context 'when application setting zoekt_auto_index_root_namespace is false' do
      before do
        stub_ee_application_setting(zoekt_auto_index_root_namespace: false)
      end

      it 'does not create any record of Search::Zoekt::EnabledNamespace' do
        expect { execute_task }.not_to change { Search::Zoekt::EnabledNamespace.count }
      end
    end

    it "creates zoekt_enabled_namespace for the root groups that don't have zoekt_enabled_namespace already" do
      expect(sub_group.root_ancestor.zoekt_enabled_namespace).to be_nil
      expect(top_group.zoekt_enabled_namespace).to be_nil
      expect(top_group2.zoekt_enabled_namespace).not_to be_nil
      expect { execute_task }.to change { Search::Zoekt::EnabledNamespace.count }.by(2)
      expect(sub_group.root_ancestor.reload.zoekt_enabled_namespace).not_to be_nil
      expect(top_group.reload.zoekt_enabled_namespace).not_to be_nil
    end
  end

  describe '#update_replica_states' do
    let(:task) { :update_replica_states }

    it 'calls ReplicaStateService.execute' do
      expect(::Search::Zoekt::ReplicaStateService).to receive(:execute)
      execute_task
    end

    context 'when zoekt replica state updates FF is disabled' do
      before do
        stub_feature_flags(zoekt_replica_state_updates: false)
      end

      it 'returns false and does not do anything' do
        expect(::Search::Zoekt::ReplicaStateService).not_to receive(:execute)
        expect(execute_task).to be(false)
      end
    end
  end

  describe '#update_index_used_storage_bytes' do
    let(:task) { :update_index_used_storage_bytes }
    let_it_be(:index) { create(:zoekt_index, :ready) }
    let_it_be(:repo) { create(:zoekt_repository, zoekt_index: index) }
    let_it_be(:another_repo) { create(:zoekt_repository, zoekt_index: index) }

    context 'when indices exists in with_stale_used_storage_bytes_updated_at' do
      it 'publishes an UpdateIndexUsedStorageBytesEvent' do
        expect(Search::Zoekt::Index).to receive_message_chain(:with_stale_used_storage_bytes_updated_at, :exists?)
          .and_return(true)
        expect { execute_task }.to publish_event(Search::Zoekt::UpdateIndexUsedStorageBytesEvent).with({})
      end
    end

    context 'when no indices exist in with_stale_used_storage_bytes_updated_at' do
      it 'does not publish an event' do
        expect(Search::Zoekt::Index).to receive_message_chain(:with_stale_used_storage_bytes_updated_at, :exists?)
          .and_return(false)
        expect { execute_task }.not_to publish_event(Search::Zoekt::UpdateIndexUsedStorageBytesEvent)
      end
    end
  end

  describe '#index_should_be_marked_as_orphaned_check' do
    let(:task) { :index_should_be_marked_as_orphaned_check }
    let_it_be_with_reload(:index) { create(:zoekt_index) }

    context 'when there are no indices that should be marked as orphaned' do
      before do
        allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
      end

      it 'does not publish any event' do
        expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task,
                                                'message' => 'Condition not met' })
        expect { execute_task }.not_to publish_event(Search::Zoekt::OrphanedIndexEvent)
      end
    end

    context 'when there are indices that should be marked as orphaned' do
      before do
        index.update_column(:zoekt_replica_id, nil)
      end

      it 'publishes Search::Zoekt::OrphanedIndexEvent event' do
        expect { execute_task }.to publish_event(Search::Zoekt::OrphanedIndexEvent).with(Hash.new({}))
      end
    end
  end

  describe '#index_to_delete_check' do
    let(:task) { :index_to_delete_check }

    context 'when indices exist in should_be_deleted scope' do
      it 'publishes an IndexMarkedAsToDeleteEvent' do
        expect(Search::Zoekt::Index).to receive_message_chain(:should_be_deleted, :exists?).and_return(true)

        expect { execute_task }
          .to publish_event(Search::Zoekt::IndexMarkedAsToDeleteEvent).with({})
      end
    end

    context 'when no indices exist in should_be_deleted_scope' do
      it 'does not publish an event' do
        expect(Search::Zoekt::Index).to receive_message_chain(:should_be_deleted, :exists?).and_return(false)

        expect { execute_task }.not_to publish_event(Search::Zoekt::IndexMarkedAsToDeleteEvent)
      end
    end
  end

  describe '#repo_should_be_marked_as_orphaned_check' do
    let(:task) { :repo_should_be_marked_as_orphaned_check }

    context 'when repositories exist in should_be_marked_as_orphaned scope' do
      it 'publishes an OrphanedRepoEvent' do
        expect(Search::Zoekt::Repository).to receive_message_chain(:should_be_marked_as_orphaned, :exists?)
                                         .and_return(true)

        expect { execute_task }
          .to publish_event(Search::Zoekt::OrphanedRepoEvent).with({})
      end
    end

    context 'when no repositories exist in should_be_marked_as_orphaned scope' do
      it 'does not publish an event' do
        expect(Search::Zoekt::Repository).to receive_message_chain(:should_be_marked_as_orphaned, :exists?)
                                         .and_return(false)

        expect { execute_task }.not_to publish_event(Search::Zoekt::OrphanedRepoEvent)
      end
    end
  end

  describe '#repo_to_delete_check' do
    let(:task) { :repo_to_delete_check }

    it 'publishes an RepoMarkedAsToDeleteEvent with repos that should be deleted' do
      expect(Search::Zoekt::Repository).to receive_message_chain(:should_be_deleted, :exists?).and_return(true)
      expect { execute_task }.to publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent).with({})
    end

    context 'when no repositories exist in should_be_deleted scope' do
      it 'does not publish an event' do
        expect(Search::Zoekt::Repository).to receive_message_chain(:should_be_deleted, :exists?).and_return(false)
        expect { execute_task }.not_to publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent)
      end
    end
  end

  describe '#lost_nodes_check', :zoekt_settings_enabled do
    let(:task) { :lost_nodes_check }
    let_it_be_with_reload(:lost_node) { create(:zoekt_node, :lost) }

    before do
      create(:zoekt_node)
    end

    it 'publishes LostNodeEvent' do
      expect { execute_task }.to publish_event(Search::Zoekt::LostNodeEvent).with({ zoekt_node_id: lost_node.id })
    end

    context 'when there are no lost nodes' do
      before do
        Search::Zoekt::Node.update_all(last_seen_at: Time.current)
      end

      it 'does not publish LostNodeEvent' do
        response = nil
        expect { response = execute_task }.to not_publish_event(Search::Zoekt::LostNodeEvent)
        expect(response).to be false
      end
    end

    context 'when on development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'does not publish LostNodeEvent' do
        expect { execute_task }.to not_publish_event(Search::Zoekt::LostNodeEvent)
      end
    end

    context 'when marking_lost_enabled? is false' do
      before do
        allow(Search::Zoekt::Node).to receive(:marking_lost_enabled?).and_return false
      end

      it 'does not publish LostNodeEvent' do
        expect { execute_task }.to not_publish_event(Search::Zoekt::LostNodeEvent)
      end
    end

    context 'when marking_lost_enabled? is true' do
      before do
        allow(Search::Zoekt::Node).to receive(:marking_lost_enabled?).and_return true
      end

      it 'publishes LostNodeEvent' do
        expect { execute_task }.to publish_event(Search::Zoekt::LostNodeEvent).with({ zoekt_node_id: lost_node.id })
      end
    end
  end

  describe '#index_mismatched_watermark_check' do
    let(:task) { :index_mismatched_watermark_check }

    context 'when no indexes have mismatched watermark levels or negative reserved storage bytes' do
      it 'does nothing, publishes no events' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::IndexWatermarkChangedEvent)
      end
    end

    context 'when indexes have mismatched watermark levels' do
      it 'publishes a Search::Zoekt::IndexWatermarkChangedEvent' do
        idx = create(:zoekt_index, :low_watermark_exceeded)
        idx.healthy!

        expect { execute_task }.to publish_event(Search::Zoekt::IndexWatermarkChangedEvent)
      end
    end

    context 'when indexes have negative reserved storage bytes' do
      it 'publishes a Search::Zoekt::IndexWatermarkChangedEvent' do
        create(:zoekt_index, :negative_reserved_storage_bytes)

        expect { execute_task }.to publish_event(Search::Zoekt::IndexWatermarkChangedEvent)
      end
    end
  end

  describe '#repo_to_index_check' do
    let(:task) { :repo_to_index_check }
    let_it_be(:pending_repo) { create(:zoekt_repository) }
    let_it_be(:initializing_repo) { create(:zoekt_repository, state: :initializing) }
    let_it_be(:ready_repo) { create(:zoekt_repository, state: :ready) }
    let_it_be(:failed_repo) { create(:zoekt_repository, state: :failed) }

    it 'publishes an RepoToIndexEvent with initializing or pending repos' do
      expect { execute_task }.to publish_event(Search::Zoekt::RepoToIndexEvent).with({})
    end

    context 'when there are no pending repos' do
      before do
        allow(Search::Zoekt::Repository).to receive_message_chain(:pending, :exists?).and_return(false)
      end

      it 'does not publish an RepoToIndexEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::RepoToIndexEvent)
      end
    end
  end

  describe '#indices_to_evict_check' do
    let(:task) { :indices_to_evict_check }
    let_it_be(:another_index) { create(:zoekt_index) }

    context 'when pending_eviction indices do not exist' do
      it 'does not publishes an IndexToEvictEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::IndexToEvictEvent)
      end
    end

    context 'when pending_eviction indices exist' do
      it 'publishes an IndexToEvictEvent' do
        create(:zoekt_index, state: :pending_eviction)

        expect { execute_task }.to publish_event(Search::Zoekt::IndexToEvictEvent).with({})
      end
    end
  end

  describe '#index_should_be_marked_as_pending_eviction_check' do
    let(:task) { :index_should_be_marked_as_pending_eviction_check }

    context 'when no indices are returned from the pending_eviction scope' do
      it 'does not publish an IndexMarkPendingEvictionEvent' do
        allow(Search::Zoekt::Index).to receive_message_chain(:should_be_pending_eviction, :exists?).and_return(false)

        expect { execute_task }.not_to publish_event(Search::Zoekt::IndexMarkPendingEvictionEvent)
      end
    end

    context 'when indices are returned from the pending eviction scope' do
      it 'publishes an IndexMarkPendingEvictionEvent' do
        allow(Search::Zoekt::Index).to receive_message_chain(:should_be_pending_eviction, :exists?).and_return(true)

        expect { execute_task }.to publish_event(Search::Zoekt::IndexMarkPendingEvictionEvent).with({})
      end
    end
  end

  describe '#adjust_indices_reserved_storage_bytes' do
    let(:task) { :adjust_indices_reserved_storage_bytes }

    context 'when should_be_reserved_storage_bytes_adjusted scope returns no indices' do
      it 'does not publishes an AdjustIndicesReservedStorageBytesEvent' do
        allow(Search::Zoekt::Index).to receive_message_chain(:should_be_reserved_storage_bytes_adjusted, :exists?)
          .and_return(false)

        expect { execute_task }.not_to publish_event(Search::Zoekt::AdjustIndicesReservedStorageBytesEvent)
      end
    end

    context 'when should_be_reserved_storage_bytes_adjusted scope returns indices' do
      it 'publishes an AdjustIndicesReservedStorageBytesEvent' do
        allow(Search::Zoekt::Index).to receive_message_chain(:should_be_reserved_storage_bytes_adjusted, :exists?)
          .and_return(true)

        expect { execute_task }.to publish_event(Search::Zoekt::AdjustIndicesReservedStorageBytesEvent).with({})
      end
    end
  end

  describe '#node_with_negative_unclaimed_storage_bytes_check' do
    let(:task) { :node_with_negative_unclaimed_storage_bytes_check }
    let_it_be(:negative_node) { create(:zoekt_node, :enough_free_space) }
    let_it_be(:_negative_index) do
      create(:zoekt_index, reserved_storage_bytes: negative_node.total_bytes * 2, node: negative_node)
    end

    let_it_be(:positive_node) { create(:zoekt_node, :enough_free_space) }
    let_it_be(:_positive_index) { create(:zoekt_index, node: positive_node) }

    it 'publishes a NodeWithNegativeUnclaimedStorageEvent for required nodes' do
      expected = {
        node_ids: [negative_node].map(&:id)
      }
      expect { execute_task }.to publish_event(Search::Zoekt::NodeWithNegativeUnclaimedStorageEvent).with(expected)
    end
  end
end
