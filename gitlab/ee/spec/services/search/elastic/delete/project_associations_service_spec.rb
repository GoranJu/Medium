# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Delete::ProjectAssociationsService, :elastic_helpers, feature_category: :global_search do
  describe '#execute' do
    subject(:execute) do
      described_class.execute({ task: :delete_project_associations,
                            project_id: project.id, traversal_id: 'random-' })
    end

    let(:work_item_index) { ::Search::Elastic::Types::WorkItem.index_name }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let(:work_item) { create(:work_item, project: project) }

    context 'when Elasticsearch is enabled', :elastic_delete_by_query do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)

        work_item
        ensure_elasticsearch_index!
      end

      context 'when there is a failure in delete' do
        let(:client) { instance_double(::Gitlab::Search::Client) }
        let(:logger) { ::Gitlab::Elasticsearch::Logger.build }

        before do
          allow(::Gitlab::Search::Client).to receive(:new).and_return(client)
          allow(client).to receive(:delete_by_query).and_return({ 'failure' => ['failed'] })
          allow(::Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger)
        end

        it 'logs the error' do
          expect(logger).to receive(:error).with(hash_including(message: "Failed to delete data for project transfer"))
          execute
        end
      end

      context 'when work_item index is available' do
        it 'raises exception and returns if both project_id and traversal_id are not passed' do
          # items are present already
          expect(items_in_index(work_item_index).count).to eq(1)
          expect(items_in_index(work_item_index)).to include(work_item.id)

          expect do
            described_class.execute({ task: :delete_project_associations, project_id: nil, traversal_id: nil })
          end.to raise_error(ArgumentError)
          es_helper.refresh_index(index_name: work_item_index)

          # items are not deleted
          expect(items_in_index(work_item_index)).to include(work_item.id)
        end

        it 'deletes work items not belonging to the passed traversal_id' do
          # items are present already
          expect(items_in_index(work_item_index).count).to eq(1)
          expect(items_in_index(work_item_index)).to include(work_item.id)

          execute
          es_helper.refresh_index(index_name: work_item_index)

          # items are deleted
          expect(items_in_index(work_item_index).count).to eq(0)
        end
      end
    end
  end
end
