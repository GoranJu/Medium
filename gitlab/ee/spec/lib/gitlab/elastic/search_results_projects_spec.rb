# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'projects', feature_category: :global_search do
  let_it_be(:user) { create(:user) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_feature_flags(search_uses_match_queries: false)
  end

  describe 'projects', :elastic_delete_by_query do
    it "returns items for project" do
      project = create :project, :repository, name: "term"
      project.add_developer(user)

      # Create issue
      create :issue, title: 'bla-bla term', project: project
      create :issue, description: 'bla-bla term', project: project
      create :issue, project: project
      # The issue I have no access to
      create :issue, title: 'bla-bla term'

      # Create Merge Request
      create :merge_request, title: 'bla-bla term', source_project: project
      create :merge_request, description: 'term in description', source_project: project, target_branch: "feature2"
      create :merge_request, source_project: project, target_branch: "feature3"
      # The merge request you have no access to
      create :merge_request, title: 'also with term'

      create :milestone, title: 'bla-bla term', project: project
      create :milestone, description: 'bla-bla term', project: project
      create :milestone, project: project
      # The Milestone you have no access to
      create :milestone, title: 'bla-bla term'

      ensure_elasticsearch_index!

      result = described_class.new(user, 'term', [project.id])

      expect(result.issues_count).to eq(2)
      expect(result.merge_requests_count).to eq(2)
      expect(result.milestones_count).to eq(2)
      expect(result.projects_count).to eq(1)
    end
  end
end
