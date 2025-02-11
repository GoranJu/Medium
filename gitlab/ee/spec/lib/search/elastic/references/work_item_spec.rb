# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::WorkItem, :elastic_helpers, feature_category: :global_search do
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:label) { create(:group_label, group: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item) { create(:work_item, :opened, labels: [label], namespace: group) }
  let_it_be(:user_work_item) { create(:work_item, :opened, labels: [label], namespace: create(:namespace)) }
  let_it_be(:project_work_item) { create(:work_item, :opened, labels: [label], project: project) }

  before do
    allow(Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
  end

  describe '#as_indexed_json' do
    let(:base_work_item_hash) do
      {
        project_id: object.reload.project_id,
        id: object.id,
        iid: object.iid,
        root_namespace_id: object.namespace_id,
        hashed_root_namespace_id: object.namespace.hashed_root_namespace_id,
        created_at: object.created_at,
        updated_at: object.updated_at,
        title: object.title,
        description: object.description,
        state: object.state,
        upvotes: object.upvotes_count,
        hidden: object.hidden?,
        work_item_type_id: object.work_item_type_id,
        correct_work_item_type_id: object.correct_work_item_type_id,
        confidential: object.confidential,
        author_id: object.author_id,
        label_ids: [label.id.to_s],
        assignee_id: object.issue_assignee_user_ids,
        due_date: object.due_date,
        traversal_ids: "#{object.namespace.id}-",
        schema_version: described_class::SCHEMA_VERSION,
        type: 'work_item'
      }
    end

    subject(:indexed_json) { described_class.new(object.id, object.es_parent).as_indexed_json.with_indifferent_access }

    describe 'user namespace work item' do
      let(:object) { user_work_item }
      let(:expected_hash) { base_work_item_hash }

      it 'serializes work_item as a hash' do
        expect(indexed_json).to match(expected_hash)
      end
    end

    describe 'group namespace work item' do
      let(:object) { work_item }
      let(:expected_hash) do
        base_work_item_hash.merge(
          root_namespace_id: parent_group.id,
          traversal_ids: "#{parent_group.id}-#{group.id}-",
          namespace_visibility_level: group.visibility_level,
          namespace_id: group.id
        )
      end

      it 'serializes work_item as a hash' do
        expect(indexed_json).to match(expected_hash)
      end
    end

    describe 'project namespace work item' do
      let(:object) { project_work_item }
      let_it_be(:note1) { create(:note_on_issue, noteable: project_work_item, project: project, note: 'Some pig') }
      let_it_be(:note2) { create(:note_on_issue, noteable: project_work_item, project: project, note: 'Terrific') }
      let_it_be(:note3) { create(:note, :internal, noteable: project_work_item, project: project, note: "Radiant") }
      let(:expected_hash) do
        base_work_item_hash.merge(
          root_namespace_id: project_work_item.namespace.root_ancestor.id,
          traversal_ids: project_work_item.namespace.elastic_namespace_ancestry,
          archived: project.archived?,
          project_visibility_level: project.visibility_level,
          issues_access_level: project.issues_access_level,
          notes: "Terrific\nSome pig",
          notes_internal: "Radiant"
        )
      end

      it 'serializes work_item as a hash' do
        expect(indexed_json).to match(expected_hash)
      end

      it 'truncates notes fields' do
        create(:note, :internal, noteable: project_work_item, project: project, note: 'Newest')

        stub_const('Search::Elastic::References::WorkItem::NOTES_MAXIMUM_BYTES', 10)

        expect(indexed_json[:notes_internal]).not_to include('Radiant')
        expect(indexed_json[:notes_internal]).to eq("Newest\n…")
      end

      it 'does not include system notes' do
        create(:note, :system, noteable: project_work_item, project: project, note: "Enchanting!")

        expect(indexed_json[:notes]).not_to include('Enchanting!')
      end

      it 'includes notes or notes_internal', :aggregate_failures do
        expect(indexed_json).to include(:notes_internal)
        expect(indexed_json).to include(:notes)
      end

      context 'when feature flag search_work_items_index_notes is false' do
        before do
          stub_feature_flags(search_work_items_index_notes: false)
        end

        it 'does not include notes or notes_internal', :aggregate_failures do
          expect(indexed_json).not_to include(:notes_internal)
          expect(indexed_json).not_to include(:notes)
        end
      end
    end
  end

  describe '#instantiate' do
    let(:work_item_ref) { described_class.new(work_item.id, work_item.es_parent) }

    it 'instantiates work item' do
      new_work_item = described_class.instantiate(work_item_ref.serialize)
      expect(new_work_item.routing).to eq(work_item.es_parent)
      expect(new_work_item.identifier).to eq(work_item.id)
    end
  end

  describe '#serialize' do
    it 'returns serialized string of work item record from class method' do
      expect(described_class.serialize(work_item)).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end

    it 'returns serialized string of work item record from instance method' do
      expect(described_class.new(work_item.id,
        work_item.es_parent).serialize).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end
  end

  describe '#model_klass' do
    it 'returns correct environment based index name from class' do
      expect(described_class.new(work_item.id, work_item.es_parent).model_klass).to eq(WorkItem)
    end
  end

  describe '#index_name' do
    it 'returns correct environment based index name from class method' do
      expect(described_class.index).to eq('gitlab-test-work_items')
    end

    it 'returns correct environment based index name from instance method' do
      expect(described_class.new(work_item.id, work_item.es_parent).index_name).to eq('gitlab-test-work_items')
    end
  end
end
