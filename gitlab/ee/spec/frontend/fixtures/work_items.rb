# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Work items", '(JavaScript fixtures)', type: :request, feature_category: :portfolio_management do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:group) { create(:group, :public) }
  let_it_be(:user) { create(:user) }

  let(:namespace_work_item_types_query_path) { 'work_items/graphql/namespace_work_item_types.query.graphql' }

  before_all do
    group.add_developer(user)
  end

  before do
    stub_licensed_features(epics: true, issue_weights: true, iterations: true, okrs: true, subepics: true)
    stub_feature_flags(okrs_mvc: true)
  end

  it 'graphql/work_items/namespace_work_item_types.query.graphql.json' do
    query = get_graphql_query_as_string(namespace_work_item_types_query_path)

    post_graphql(query, current_user: user, variables: { fullPath: group.full_path })

    expect_graphql_errors_to_be_empty
  end

  context 'with okrs' do
    before do
      stub_licensed_features(epics: true, issue_weights: true, iterations: true, okrs: true)
      stub_feature_flags(okrs_mvc: true)
    end

    let_it_be(:project) { create(:project, :public, namespace: group) }

    it 'graphql/work_items/okrs/namespace_work_item_types.query.graphql.json' do
      query = get_graphql_query_as_string(namespace_work_item_types_query_path)

      post_graphql(query, current_user: user, variables: { fullPath: project.full_path })

      expect_graphql_errors_to_be_empty
    end
  end
end
