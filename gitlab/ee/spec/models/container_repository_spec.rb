# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRepository, feature_category: :geo_replication do
  include_examples 'a verifiable model with a separate table for verification state' do
    let(:verifiable_model_record) { build(:container_repository) }
    let(:unverifiable_model_record) { nil }
  end

  describe '.replicables_for_current_secondary' do
    let(:secondary) { create(:geo_node, :secondary) }

    let_it_be(:synced_group) { create(:group) }
    let_it_be(:nested_group) { create(:group, parent: synced_group) }
    let_it_be(:synced_project) { create(:project, group: synced_group) }
    let_it_be(:synced_project_in_nested_group) { create(:project, group: nested_group) }
    let_it_be(:unsynced_project) { create(:project) }
    let_it_be(:project_broken_storage) { create(:project, :broken_storage) }

    let_it_be(:container_repository_1) { create(:container_repository, project: synced_project) }
    let_it_be(:container_repository_2) { create(:container_repository, project: synced_project_in_nested_group) }
    let_it_be(:container_repository_3) { create(:container_repository, project: unsynced_project) }
    let_it_be(:container_repository_4) { create(:container_repository, project: project_broken_storage) }

    before do
      stub_current_geo_node(secondary)
      stub_registry_replication_config(enabled: true)
    end

    context 'with registry replication disabled' do
      before do
        stub_registry_replication_config(enabled: false)
      end

      it 'returns an empty relation' do
        replicables =
          described_class.replicables_for_current_secondary(described_class.minimum(:id)..described_class.maximum(:id))

        expect(replicables).to be_empty
      end
    end

    context 'without selective sync' do
      it 'returns all container repositories' do
        expected = [container_repository_1, container_repository_2, container_repository_3, container_repository_4]

        replicables =
          described_class.replicables_for_current_secondary(described_class.minimum(:id)..described_class.maximum(:id))

        expect(replicables).to match_array(expected)
      end
    end

    context 'with selective sync by namespace' do
      before do
        secondary.update!(selective_sync_type: 'namespaces', namespaces: [synced_group])
      end

      it 'excludes container repositories that are not in selectively synced projects' do
        expected = [container_repository_1, container_repository_2]

        replicables =
          described_class.replicables_for_current_secondary(described_class.minimum(:id)..described_class.maximum(:id))

        expect(replicables).to match_array(expected)
      end
    end

    context 'with selective sync by shard' do
      before do
        secondary.update!(selective_sync_type: 'shards', selective_sync_shards: ['broken'])
      end

      it 'excludes container repositories that are not in selectively synced shards' do
        expected = [container_repository_4]

        replicables =
          described_class.replicables_for_current_secondary(described_class.minimum(:id)..described_class.maximum(:id))

        expect(replicables).to match_array(expected)
      end
    end
  end

  describe '.search' do
    let_it_be(:container_repository1) { create(:container_repository) }
    let_it_be(:container_repository2) { create(:container_repository) }
    let_it_be(:container_repository3) { create(:container_repository) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(container_repository1, container_repository2, container_repository3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all container repositories' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches' do
        context 'with matches by attributes' do
          where(:searchable_attributes) { described_class::EE_SEARCHABLE_ATTRIBUTES }

          before do
            # Use update_column to bypass attribute validations like regex formatting, checksum, etc.
            container_repository1.update_column(searchable_attributes, 'any_keyword')
          end

          with_them do
            it do
              result = described_class.search('any_keyword')

              expect(result).to contain_exactly(container_repository1)
            end
          end
        end
      end
    end
  end

  describe '#push_blob' do
    it "calls client's push blob with path passed" do
      gitlab_container_repository = create(:container_repository)
      client = instance_double("ContainerRegistry::Client")
      allow(gitlab_container_repository).to receive(:client).and_return(client)

      expect(client).to receive(:push_blob).with(gitlab_container_repository.path, 'a123cd', ['body'], 32456)

      gitlab_container_repository.push_blob('a123cd', ['body'], 32456)
    end
  end
end
