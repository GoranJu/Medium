# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::Node, feature_category: :global_search do
  let_it_be_with_reload(:node) do
    create(:zoekt_node, index_base_url: 'http://example.com:1234/', search_base_url: 'http://example.com:4567/')
  end

  let_it_be(:indexed_namespace1) { create(:namespace) }
  let_it_be(:indexed_namespace2) { create(:namespace) }
  let_it_be(:unindexed_namespace) { create(:namespace) }
  let_it_be(:enabled_namespace1) { create(:zoekt_enabled_namespace, namespace: indexed_namespace1) }
  let_it_be(:zoekt_index) { create(:zoekt_index, :ready, node: node, zoekt_enabled_namespace: enabled_namespace1) }

  before do
    enabled_namespace2 = create(:zoekt_enabled_namespace, namespace: indexed_namespace2)
    create(:zoekt_index, :ready, node: node, zoekt_enabled_namespace: enabled_namespace2)
  end

  describe 'relations' do
    it { is_expected.to have_many(:indices).inverse_of(:node) }
    it { is_expected.to have_many(:tasks).inverse_of(:node) }
    it { is_expected.to have_many(:enabled_namespaces).through(:indices) }
    it { is_expected.to have_many(:zoekt_repositories).through(:indices) }
  end

  describe 'scopes' do
    describe '.lost', :freeze_time do
      let_it_be(:offline_node) { create(:zoekt_node, last_seen_at: 10.minutes.ago) }
      let_it_be(:lost_node) { create(:zoekt_node, :lost) }

      it 'returns all the lost nodes' do
        expect(described_class.lost).to contain_exactly(lost_node)
      end
    end

    describe '.online', :freeze_time do
      let_it_be(:online_node) { create(:zoekt_node) }
      let_it_be(:offline_node) { create(:zoekt_node, :offline) }

      it 'returns nodes considered to be online' do
        expect(described_class.online).to contain_exactly(node, online_node)
      end
    end

    describe '.searchable', :freeze_time do
      let_it_be(:searchable_node) { create(:zoekt_node) }
      let_it_be(:non_searchable_node) { create(:zoekt_node, :offline) }

      it 'returns nodes considered to be searchable' do
        expect(described_class.searchable).to include searchable_node
        expect(described_class.searchable).not_to include non_searchable_node
      end
    end

    describe '.by_name' do
      let_it_be(:node1) { create(:zoekt_node, metadata: { name: 'node1' }) }
      let_it_be(:node2) { create(:zoekt_node, metadata: { name: 'node2' }) }
      let_it_be(:node3) { create(:zoekt_node, metadata: { name: 'node3' }) }

      it 'returns nodes filtered by name' do
        expect(described_class.by_name('node1')).to contain_exactly(node1)
        expect(described_class.by_name('node1', 'node2')).to contain_exactly(node1, node2)
        expect(described_class.by_name('non_existent')).to be_empty
      end
    end

    describe '.searchable_for_project' do
      let_it_be(:project) { create(:project, namespace: indexed_namespace1) }
      let_it_be(:zoekt_index) { create(:zoekt_index) }

      context 'when zoekt_repository for the given project does not exists' do
        it 'is empty' do
          expect(described_class.searchable_for_project(project)).to be_empty
        end
      end

      context 'when zoekt_repository for the given project exists' do
        let_it_be_with_reload(:zoekt_repository) do
          create(:zoekt_repository, project: project, zoekt_index: zoekt_index)
        end

        context 'when there is no ready repository' do
          it 'is empty' do
            expect(described_class.searchable_for_project(project)).to be_empty
          end
        end

        context 'when there is a ready repository' do
          before do
            zoekt_repository.ready!
          end

          it 'returns the nodes' do
            expect(described_class.searchable_for_project(project)).not_to be_empty
          end

          context 'when there is no online nodes' do
            before do
              Search::Zoekt::Node.update_all(last_seen_at: Search::Zoekt::Node::ONLINE_DURATION_THRESHOLD.ago - 1.hour)
            end

            it 'is empty' do
              expect(described_class.searchable_for_project(project)).to be_empty
            end
          end
        end
      end
    end

    describe '.negative_unclaimed_storage_bytes' do
      let_it_be(:negative_node) { create(:zoekt_node, :enough_free_space) }
      let_it_be(:_negative_index) do
        create(:zoekt_index, reserved_storage_bytes: negative_node.total_bytes * 2, node: negative_node)
      end

      let_it_be(:positive_node) { create(:zoekt_node, :enough_free_space) }
      let_it_be(:_positive_index) { create(:zoekt_index, node: positive_node) }

      it 'includes only nodes with negative unclaimed storage' do
        expect(described_class.negative_unclaimed_storage_bytes).to contain_exactly(node, negative_node)
      end

      it 'does not include nodes with positive unclaimed storage' do
        expect(described_class.negative_unclaimed_storage_bytes).not_to include(positive_node)
      end
    end

    describe '.with_positive_unclaimed_storage_bytes' do
      let_it_be(:node_with_positive_storage) { create(:zoekt_node, :enough_free_space) }
      let_it_be(:node_with_zero_storage) { create(:zoekt_node, total_bytes: 1000, used_bytes: 1000) }
      let_it_be(:node_with_negative_storage) { create(:zoekt_node, :enough_free_space) }

      before do
        # Scenario with positive unclaimed storage
        create(:zoekt_index,
          node: node_with_positive_storage,
          reserved_storage_bytes: node_with_positive_storage.total_bytes / 2
        )

        # Scenario with negative unclaimed storage
        create(:zoekt_index,
          node: node_with_negative_storage,
          reserved_storage_bytes: node_with_negative_storage.total_bytes * 2
        )
      end

      it 'returns only nodes with non-negative unclaimed storage bytes' do
        positive_nodes = described_class.with_positive_unclaimed_storage_bytes

        expect(positive_nodes).to include(node_with_positive_storage)
        expect(positive_nodes).to include(node_with_zero_storage)
        expect(positive_nodes).not_to include(node_with_negative_storage)
      end

      it 'adds unclaimed_storage_bytes attribute to returned nodes' do
        result = described_class.with_positive_unclaimed_storage_bytes.find(node_with_positive_storage.id)

        expect(result).to respond_to(:unclaimed_storage_bytes)
        expect(result.unclaimed_storage_bytes).to be >= 0
      end

      it 'calculates unclaimed_storage_bytes correctly' do
        result = described_class.with_positive_unclaimed_storage_bytes.find(node_with_positive_storage.id)

        # Manual calculation to verify the scope's calculation
        expected_unclaimed_bytes = node_with_positive_storage.total_bytes -
          node_with_positive_storage.used_bytes +
          node_with_positive_storage.indexed_bytes -
          node_with_positive_storage.indices.sum(:reserved_storage_bytes)

        expect(result.unclaimed_storage_bytes).to eq(expected_unclaimed_bytes)
      end

      it 'groups results by node id to handle multiple indices' do
        # Create multiple indices for the same node
        create(:zoekt_index,
          node: node_with_positive_storage,
          reserved_storage_bytes: node_with_positive_storage.total_bytes / 4
        )

        results = described_class.with_positive_unclaimed_storage_bytes

        expect(results).to include(node_with_positive_storage)
      end

      context 'when no indices exist' do
        let_it_be(:node_without_indices) { create(:zoekt_node, :enough_free_space) }

        it 'includes nodes without indices if they have positive unclaimed storage' do
          results = described_class.with_positive_unclaimed_storage_bytes

          expect(results).to include(node_without_indices)
        end
      end
    end
  end

  describe 'validations' do
    describe 'metadata' do
      it { expect(described_class).to validate_jsonb_schema(['zoekt_node_metadata']) }
    end
  end

  describe '.find_or_initialize_by_task_request', :freeze_time do
    let(:base_params) do
      {
        'uuid' => '3869fe21-36d1-4612-9676-0b783ef2dcd7',
        'node.name' => 'm1.local',
        'node.url' => 'http://localhost:6080',
        'disk.all' => 994662584320,
        'disk.free' => 461988872192,
        'disk.used' => 532673712128,
        'node.task_count' => 5,
        'node.concurrency' => 10
      }
    end

    subject(:tasked_node) { described_class.find_or_initialize_by_task_request(params) }

    context 'when node.search_url is unset' do
      let(:params) { base_params }

      it 'returns a new record with correct base_urls' do
        expect(tasked_node).not_to be_persisted
        expect(tasked_node.index_base_url).to eq(params['node.url'])
        expect(tasked_node.search_base_url).to eq(params['node.url'])
      end
    end

    context 'when node.search_url is set' do
      let(:params) { base_params.merge('node.search_url' => 'http://localhost:6090') }

      context 'when node does not exist for given UUID' do
        it 'returns a new record with correct attributes' do
          expect(tasked_node).not_to be_persisted
          expect(tasked_node.index_base_url).to eq(params['node.url'])
          expect(tasked_node.search_base_url).to eq(params['node.search_url'])
          expect(tasked_node.uuid).to eq(params['uuid'])
          expect(tasked_node.last_seen_at).to eq(Time.zone.now)
          expect(tasked_node.used_bytes).to eq(params['disk.used'])
          expect(tasked_node.total_bytes).to eq(params['disk.all'])
          expect(tasked_node.indexed_bytes).to eq 0
          expect(tasked_node.metadata['name']).to eq(params['node.name'])
          expect(tasked_node.metadata['task_count']).to eq(params['node.task_count'])
          expect(tasked_node.metadata['concurrency']).to eq(params['node.concurrency'])
        end
      end

      context 'when node already exists for given UUID' do
        it 'returns existing node and updates correct attributes' do
          node.update!(uuid: params['uuid'])

          expect(tasked_node).to be_persisted
          expect(tasked_node.id).to eq(node.id)
          expect(tasked_node.index_base_url).to eq(params['node.url'])
          expect(tasked_node.search_base_url).to eq(params['node.search_url'])
          expect(tasked_node.uuid).to eq(params['uuid'])
          expect(tasked_node.last_seen_at).to eq(Time.zone.now)
          expect(tasked_node.used_bytes).to eq(params['disk.used'])
          expect(tasked_node.total_bytes).to eq(params['disk.all'])
          expect(tasked_node.indexed_bytes).to eq 0
          expect(tasked_node.metadata['name']).to eq(params['node.name'])
        end

        it 'allows creation of another node with the same URL' do
          node.update!(index_base_url: params['node.url'], search_base_url: params['node.url'])

          expect(tasked_node.save).to eq(true)
        end
      end
    end

    context 'when disk.indexed is present' do
      let(:params) { base_params.merge('disk.indexed' => 2416879) }

      it 'sets indexed_bytes to the disk.indexed from params' do
        expect(tasked_node.indexed_bytes).to eq(params['disk.indexed'])
      end
    end
  end

  describe '.marking_lost_enabled?', :zoekt_settings_enabled do
    it 'returns true' do
      expect(described_class.marking_lost_enabled?).to eq true
    end

    context 'when FF zoekt_internal_api_register_nodes is disabled' do
      before do
        stub_feature_flags(zoekt_internal_api_register_nodes: false)
      end

      it 'returns false' do
        expect(described_class.marking_lost_enabled?).to eq false
      end
    end

    context 'when application setting zoekt_indexing_paused? is enabled' do
      before do
        stub_ee_application_setting(zoekt_indexing_paused: true)
      end

      it 'returns false' do
        expect(described_class.marking_lost_enabled?).to eq false
      end
    end

    context 'when application setting zoekt_indexing_enabled? is disabled' do
      before do
        stub_ee_application_setting(zoekt_indexing_enabled: false)
      end

      it 'returns false' do
        expect(described_class.marking_lost_enabled?).to eq false
      end
    end

    context 'when application setting zoekt_auto_delete_lost_nodes? is disabled' do
      before do
        stub_ee_application_setting(zoekt_auto_delete_lost_nodes: false)
      end

      it 'returns false' do
        expect(described_class.marking_lost_enabled?).to eq false
      end
    end
  end

  describe '#backoff' do
    it 'returns a NodeBackoff' do
      expect(::Search::Zoekt::NodeBackoff).to receive(:new).with(node).and_return(:backoff)
      expect(node.backoff).to eq(:backoff)
    end
  end

  describe '#metadata_json' do
    it 'returns a json with metadata' do
      node.update!(metadata: { name: 'test_name', task_count: 100, concurrency: 10 })
      expected_json = {
        'zoekt.node_name' => 'test_name',
        'zoekt.node_id' => node.id,
        'zoekt.indexed_bytes' => 0,
        'zoekt.storage_percent_used' => node.storage_percent_used,
        'zoekt.used_bytes' => node.used_bytes,
        'zoekt.total_bytes' => node.total_bytes,
        'zoekt.task_count' => 100,
        'zoekt.concurrency' => 10,
        'zoekt.concurrency_limit' => 10
      }

      expect(node.metadata_json).to eq(expected_json)
    end

    it 'does not return empty keys' do
      node.update!(metadata: { name: 'another_name' })
      expected_json = {
        'zoekt.node_name' => 'another_name',
        'zoekt.node_id' => node.id,
        'zoekt.indexed_bytes' => 0,
        'zoekt.storage_percent_used' => node.storage_percent_used,
        'zoekt.used_bytes' => node.used_bytes,
        'zoekt.total_bytes' => node.total_bytes,
        'zoekt.concurrency_limit' => node.concurrency_limit
      }

      expect(node.metadata_json).to eq(expected_json)
    end
  end

  describe '#concurrency_limit' do
    subject(:concurrency_limit) { node.concurrency_limit }

    context 'when node does not have task_count/concurrency set' do
      it 'returns the default limit' do
        expect(concurrency_limit).to eq(::Search::Zoekt::Node::DEFAULT_CONCURRENCY_LIMIT)
      end
    end

    context 'when node has task_count/concurrency set' do
      using RSpec::Parameterized::TableSyntax

      where(:concurrency, :concurrency_override, :multiplier, :result) do
        10  | nil | 1.0 | 10
        10  | nil | 1.5 | 15
        10  | nil | 2.0 | 20
        10  | 0   | 3.5 | 35
        3   | 0   | 2.5 | 8
        3   | 0   | 2.4 | 7
        1   | nil | 1.0 | 1
        1   | nil | 2.0 | 2
        10  | 20  | 1.5 | 20
        200 | nil | 1.0 | ::Search::Zoekt::Node::MAX_CONCURRENCY_LIMIT
        200 | nil | 1.5 | ::Search::Zoekt::Node::MAX_CONCURRENCY_LIMIT
        0   | nil | 1.5 | ::Search::Zoekt::Node::DEFAULT_CONCURRENCY_LIMIT
      end

      with_them do
        before do
          stub_ee_application_setting(zoekt_cpu_to_tasks_ratio: multiplier)
          node.metadata['concurrency'] = concurrency
          node.metadata['concurrency_override'] = concurrency_override
        end

        it 'returns correct value' do
          expect(concurrency_limit).to eq(result)
        end
      end
    end
  end

  describe '#storage_percent_used' do
    it 'is used storage / total reserved storage' do
      expect(node.storage_percent_used).to eq(node.used_bytes / node.total_bytes.to_f)
    end
  end

  describe '#watermark_exceeded_low?' do
    it 'returns true when over low limit' do
      node.used_bytes = 0
      expect(node).not_to be_watermark_exceeded_low

      node.used_bytes = node.total_bytes * ::Search::Zoekt::Node::WATERMARK_LIMIT_LOW
      expect(node).to be_watermark_exceeded_low
      expect(node).not_to be_watermark_exceeded_high
      expect(node).not_to be_watermark_exceeded_critical
    end
  end

  describe '#watermark_exceeded_high?' do
    it 'returns true when over high limit' do
      node.used_bytes = 0
      expect(node).not_to be_watermark_exceeded_high

      node.used_bytes = node.total_bytes * ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH
      expect(node).to be_watermark_exceeded_low
      expect(node).to be_watermark_exceeded_high
      expect(node).not_to be_watermark_exceeded_critical
    end
  end

  describe '#unclaimed_storage_bytes' do
    it 'returns reservable storage' do
      allow(node).to receive(:reserved_storage_bytes).and_return(500)

      node.total_bytes = 1000
      node.used_bytes = 100
      node.indexed_bytes = 200

      expect(node.unclaimed_storage_bytes).to eq(600)
    end
  end

  describe '#watermark_exceeded_critical?' do
    it 'returns true when over critical limit' do
      node.used_bytes = 0
      expect(node).not_to be_watermark_exceeded_critical

      node.used_bytes = node.total_bytes * ::Search::Zoekt::Node::WATERMARK_LIMIT_CRITICAL
      expect(node).to be_watermark_exceeded_low
      expect(node).to be_watermark_exceeded_high
      expect(node).to be_watermark_exceeded_critical
    end
  end

  describe '#task_pull_frequency' do
    before do
      node.metadata['concurrency_override'] = 1
      node.save!
    end

    context 'when feature flag zoekt_reduced_pull_frequency is disabled' do
      before do
        stub_feature_flags(zoekt_reduced_pull_frequency: false)
        create_list(:zoekt_task, 2, node: node)
      end

      it 'returns default pull frequency' do
        expect(node.task_pull_frequency).to eq described_class::TASK_PULL_FREQUENCY_DEFAULT
      end
    end

    context 'when pending tasks is more than the concurrency_limit of a node' do
      before do
        create_list(:zoekt_task, 2, node: node)
      end

      it 'returns increased pull frequency' do
        expect(node.task_pull_frequency).to eq described_class::TASK_PULL_FREQUENCY_INCREASED
      end
    end

    context 'when pending tasks is equal to the concurrency_limit of a node' do
      before do
        create(:zoekt_task, node: node)
      end

      it 'returns increased pull frequency' do
        expect(node.task_pull_frequency).to eq described_class::TASK_PULL_FREQUENCY_INCREASED
      end
    end

    context 'when pending tasks is less than the concurrency_limit of a node' do
      it 'returns default pull frequency' do
        expect(node.task_pull_frequency).to eq described_class::TASK_PULL_FREQUENCY_DEFAULT
      end
    end
  end

  describe '#save_debounce', :freeze_time do
    context 'when record is persisted' do
      context 'when difference between updated_at and current time is more than DEBOUNCE_DELAY' do
        before do
          node.update_column :updated_at, (described_class::DEBOUNCE_DELAY + 1.second).ago
        end

        it 'returns true and calls save' do
          expect(node).to receive(:save).and_call_original
          expect(node.save_debounce).to be true
        end
      end

      context 'when difference between updated_at and current time is less than DEBOUNCE_DELAY' do
        before do
          node.update_column :updated_at, (described_class::DEBOUNCE_DELAY - 1.second).ago
        end

        it 'returns true and does not calls save' do
          expect(node).not_to receive(:save)
          expect(node.save_debounce).to be true
        end
      end
    end

    context 'when record is not persisted' do
      let(:new_node) { build(:zoekt_node) }

      it 'calls save' do
        expect(new_node).to receive(:save)
        new_node.save_debounce
      end
    end
  end
end
