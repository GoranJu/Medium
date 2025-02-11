# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issue, :elastic_delete_by_query, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  let_it_be(:admin) { create :user, :admin }

  let(:project) { create :project, :public }

  it_behaves_like 'limited indexing is enabled' do
    let_it_be(:object) { create :issue, project: project }
  end

  describe 'search results' do
    it 'searches issues', :sidekiq_inline, :aggregate_failures do
      create :issue, title: 'bla-bla term1', project: project
      create :issue, description: 'bla-bla term2', project: project
      create :issue, project: project

      # The issue I have no access to except as an administrator
      create :issue, title: 'bla-bla term3', project: create(:project, :private)

      ensure_elasticsearch_index!

      options = { project_ids: [project.id], search_level: 'global' }

      expect(described_class.elastic_search('(term1 | term2 | term3) +bla-bla', options: options).total_count).to eq(2)
      expect(described_class.elastic_search(described_class.last.to_reference, options: options).total_count).to eq(1)
      expect(described_class.elastic_search('bla-bla',
        options: { search_level: 'global', project_ids: :any,
                   public_and_internal_projects: true }).total_count).to eq(3)
    end

    it 'searches by iid and scopes to type: issue only', :sidekiq_inline do
      issue = create :issue, title: 'bla-bla issue', project: project
      create :issue, description: 'term2 in description', project: project

      # MergeRequest with the same iid should not be found in Issue search
      create :merge_request, title: 'bla-bla', source_project: project, iid: issue.iid

      ensure_elasticsearch_index!

      # User needs to be admin or the MergeRequest would just be filtered by
      # confidential: false
      options = { project_ids: [project.id], current_user: admin, search_level: 'global' }

      results = described_class.elastic_search("##{issue.iid}", options: options)
      expect(results.total_count).to eq(1)
      expect(results.first.id).to eq(issue.id.to_s)
    end

    it_behaves_like 'no results when the user cannot read cross project' do
      let(:record1) { create(:issue, project: project, title: 'test-issue') }
      let(:record2) { create(:issue, project: project2, title: 'test-issue') }
    end
  end

  describe 'as_indexed_json' do
    let_it_be(:assignee) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, :internal, namespace: subgroup) }
    let_it_be(:label) { create(:label) }

    let_it_be(:issue) do
      create(:labeled_issue, project: project, assignees: [assignee],
        labels: [label], description: 'The description is too long')
    end

    let_it_be(:award_emoji) { create(:award_emoji, :upvote, awardable: issue) }

    let(:expected_hash) do
      issue.attributes.extract!(
        'id',
        'iid',
        'title',
        'description',
        'created_at',
        'updated_at',
        'project_id',
        'author_id',
        'confidential'
      ).merge({
        'type' => issue.es_type,
        'state' => issue.state,
        'upvotes' => 1,
        'namespace_ancestry_ids' => "#{group.id}-#{subgroup.id}-",
        'label_ids' => [label.id.to_s],
        'schema_version' => Elastic::Latest::IssueInstanceProxy::SCHEMA_VERSION,
        'assignee_id' => [assignee.id],
        'issues_access_level' => ProjectFeature::ENABLED,
        'visibility_level' => Gitlab::VisibilityLevel::INTERNAL,
        'hashed_root_namespace_id' => issue.project.namespace.hashed_root_namespace_id,
        'hidden' => issue.hidden?,
        'archived' => issue.project.archived?,
        'routing' => issue.es_parent,
        'work_item_type_id' => issue.work_item_type_id
      })
    end

    it 'returns empty hash if project is nil' do
      issue.project = nil

      expect(issue.__elasticsearch__.as_indexed_json).to eq({})

      issue.project = project
    end

    it 'returns json with all needed elements' do
      expect(issue.__elasticsearch__.as_indexed_json).to eq(expected_hash)
    end

    it 'contains the expected mappings' do
      optional_fields = Elastic::Latest::IssueInstanceProxy::OPTIONAL_FIELDS
      issue_proxy = Elastic::Latest::ApplicationClassProxy.new(described_class, use_separate_indices: true)
      expected_keys = issue_proxy.mappings.to_hash[:properties].keys.map(&:to_s) - optional_fields

      keys = issue.__elasticsearch__.as_indexed_json.keys
      expect(keys).to match_array(expected_keys)
    end

    it 'handles a project missing project_feature', :aggregate_failures do
      allow(issue.project).to receive(:project_feature).and_return(nil)

      expect { issue.__elasticsearch__.as_indexed_json }.not_to raise_error
      expect(issue.__elasticsearch__.as_indexed_json['issues_access_level']).to eq(ProjectFeature::PRIVATE)
    end

    context 'when there is an elasticsearch_indexed_field_length limit' do
      it 'truncates to the default plan limit' do
        stub_ee_application_setting(elasticsearch_indexed_field_length_limit: 10)

        expect(issue.__elasticsearch__.as_indexed_json['description']).to eq('The descri')
      end
    end

    context 'when the elasticsearch_indexed_field_length limit is 0' do
      it 'does not truncate the fields' do
        stub_ee_application_setting(elasticsearch_indexed_field_length_limit: 0)

        expect(issue.__elasticsearch__.as_indexed_json['description']).to eq('The description is too long')
      end
    end
  end
end
