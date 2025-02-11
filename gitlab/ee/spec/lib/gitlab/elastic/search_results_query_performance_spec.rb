# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'query performance', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:limit_project_ids) { [project.id] }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_feature_flags(search_uses_match_queries: false)
  end

  describe 'query performance' do
    let(:results) { described_class.new(user, query, limit_project_ids) }

    include_examples 'does not hit Elasticsearch twice for objects and counts',
      %w[projects notes blobs wiki_blobs commits issues merge_requests milestones]
    include_examples 'does not load results for count only queries',
      %w[projects notes blobs wiki_blobs commits issues merge_requests milestones]
  end
end
