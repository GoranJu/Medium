# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::InitialIndexingEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let_it_be(:namespace) { create(:group, :with_hierarchy, children: 1, depth: 3) }
  let(:event) { Search::Zoekt::InitialIndexingEvent.new(data: data) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be_with_reload(:zoekt_index) do
    create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, namespace_id: namespace.id)
  end

  let(:data) do
    { index_id: zoekt_index.id }
  end

  before do
    [namespace, namespace.children.first, namespace.children.first.children.first].each do |n|
      create(:project, namespace: n)
      create(:project_namespace)
    end
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when metadata does not have project_namespace_id_from and project_namespace_id_to' do
      it 'creates pending zoekt_repositories for each project move the index to initializing' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).count).to eq namespace.all_project_ids.count
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end
    end

    context 'when metadata has project_namespace_id_from and project_namespace_id_to' do
      let(:pn_id_from) { project_namespace_ids_for_namespace(namespace).first }
      let(:pn_id_to) { project_namespace_ids_for_namespace(namespace).second }
      let(:expected_project_ids) do
        Namespaces::ProjectNamespace.where(id: pn_id_from..pn_id_to).filter_map do |p_ns|
          p_ns.project.id if p_ns.project.root_ancestor == namespace
        end
      end

      before do
        zoekt_index.update!(metadata: { project_namespace_id_from: pn_id_from, project_namespace_id_to: pn_id_to })
      end

      it 'creates pending zoekt_repositories for projects whose project_namespace is in range (pn_id_from..pn_id_to)' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).pluck(:project_id)).to match_array(expected_project_ids)
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end

      context 'when number of projects is larger than the batch size' do
        let(:first_project_id) { Namespaces::ProjectNamespace.find(pn_id_from).project.id }

        before do
          stub_const("#{described_class}::BATCH_SIZE", 1)
          stub_const("#{described_class}::INSERT_LIMIT", 1)
        end

        it 'creates one zoekt repository and does not change index state when batch size is 1' do
          expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
          expect { consume_event(subscriber: described_class, event: event) }
            .not_to change { zoekt_index.reload.state }.from('pending')
          expect(zoekt_repositories_for_index(zoekt_index).pluck(:project_id)).to contain_exactly(first_project_id)
          expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
        end
      end
    end

    context 'when metadata has only project_namespace_id_from' do
      let(:pn_id_from) { project_namespace_ids_for_namespace(namespace).first }
      let(:expected_project_ids) do
        Namespaces::ProjectNamespace.where(id: pn_id_from..).filter_map do |p_ns|
          p_ns.project.id if p_ns.project.root_ancestor == namespace
        end
      end

      before do
        zoekt_index.update!(metadata: { project_namespace_id_from: pn_id_from })
      end

      it 'creates pending zoekt_repositories for projects whose project_namespace is in range (pn_id_from..)' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).pluck(:project_id)).to match_array(expected_project_ids)
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end
    end

    context 'when index is not in pending' do
      let(:data) do
        { index_id: zoekt_index.id }
      end

      before do
        zoekt_index.initializing!
      end

      it 'does not creates zoekt_repositories' do
        consume_event(subscriber: described_class, event: event)
        expect(zoekt_repositories_for_index(zoekt_index).count).to eq 0
      end
    end

    context 'when index can not be found' do
      let(:data) do
        { index_id: non_existing_record_id }
      end

      it 'does not creates zoekt_repositories' do
        consume_event(subscriber: described_class, event: event)
        expect(zoekt_repositories_for_index(zoekt_index).count).to eq 0
      end
    end
  end

  def zoekt_repositories_for_index(index)
    Search::Zoekt::Repository.where(zoekt_index_id: index.id)
  end

  def project_namespace_ids_for_namespace(namespace)
    Namespaces::ProjectNamespace.select { |pn| pn.root_ancestor == namespace }.map(&:id).sort
  end
end
