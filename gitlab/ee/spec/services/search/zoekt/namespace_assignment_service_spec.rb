# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::NamespaceAssignmentService, feature_category: :global_search do
  let_it_be(:namespace) { create(:group, :with_hierarchy, children: 1, depth: 3) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be(:project) { create(:project, :repository, namespace: namespace) }
  let_it_be_with_reload(:project2) { create(:project, :repository, namespace: namespace.children.first) }
  let_it_be_with_reload(:project3) { create(:project, :repository, namespace: namespace) }
  let_it_be_with_reload(:project4) { create(:project, :repository, namespace: namespace.children.first) }
  let_it_be_with_reload(:project5) { create(:project, :repository, namespace: namespace.children.first.children.first) }
  let(:service) { described_class.new(zoekt_enabled_namespace) }

  before do
    create(:project_statistics, project: project, with_data: true)
    create(:project_statistics, project: project2, with_data: true, size_multiplier: 10)
    create(:project_statistics, project: project3, with_data: true, size_multiplier: 10)
    create(:project_statistics, project: project4, with_data: true, size_multiplier: 10)
    create(:project_statistics, project: project5, with_data: true, size_multiplier: 10)
  end

  describe '#execute' do
    subject(:collection) { described_class.new(zoekt_enabled_namespace).execute }

    context 'when nodes are not enough' do
      before do
        create_list(:zoekt_node, 3)
      end

      it 'returns empty collection' do
        expect(collection).to be_empty
      end
    end

    context 'when there are enough nodes' do
      before do
        create_list(:zoekt_node, described_class::MAX_INDICES_PER_REPLICA + 1)
      end

      context 'when a namespace can be accommodated within 5 nodes' do
        context 'when at least one project does not have statistics' do
          before do
            project3.statistics.destroy!
          end

          it 'returns empty collection' do
            expect(collection).to be_empty
          end
        end

        it 'creates multiple indices to accommodate all projects' do
          expect(collection).not_to be_empty
          expect(collection.pluck(:namespace_id).uniq).to contain_exactly namespace.id
          expect(collection.pluck(:zoekt_enabled_namespace_id).uniq).to contain_exactly zoekt_enabled_namespace.id
          expect(collection.pluck(:namespace_id).uniq).to contain_exactly namespace.id
          expect(collection.pluck(:zoekt_replica_id).uniq).to contain_exactly zoekt_enabled_namespace.replicas.last.id
          expect(collection[0].metadata).to eq({ project_id_from: project.id, project_id_to: project2.id })
          expect(collection[1].metadata).to eq({ project_id_from: project3.id, project_id_to: project3.id })
          expect(collection[2].metadata).to eq({ project_id_from: project4.id, project_id_to: project4.id })
          expect(collection[3].metadata).to eq({ project_id_from: project5.id })
        end
      end

      context 'when a namespace can not be accommodated within 5 nodes' do
        context 'when one of the projects is too big to fit into any node' do
          before do
            project3.statistics.update_column :repository_size, 100
          end

          it 'returns empty collection' do
            expect(collection).to be_empty
          end
        end

        context 'when there are too many projects' do
          let_it_be(:project6) { create(:project, :repository, namespace: namespace) }
          let_it_be(:project7) { create(:project, :repository, namespace: namespace.children.first) }

          before do
            create(:project_statistics, project: project6, with_data: true, size_multiplier: 10)
            create(:project_statistics, project: project7, with_data: true, size_multiplier: 10)
          end

          it 'returns empty collection' do
            expect(collection).to be_empty
          end
        end
      end

      context 'when indices is over pre ready limit' do
        before do
          allow(Search::Zoekt::Index)
            .to receive_message_chain(:pre_ready, :count)
            .and_return(described_class::PRE_READY_LIMIT + 1)
        end

        it 'returns empty collection' do
          expect(collection).to be_empty
        end
      end
    end
  end

  describe '.execute' do
    it 'passes arguments to new and calls execute' do
      expect(described_class).to receive(:new).with(zoekt_enabled_namespace).and_return(service)
      expect(service).to receive(:execute)
      described_class.execute(zoekt_enabled_namespace)
    end
  end
end
