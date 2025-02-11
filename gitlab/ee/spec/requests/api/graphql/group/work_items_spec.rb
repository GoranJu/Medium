# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a work item list for a group', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :public) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, :repository, :public, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }

  let(:work_items_data) { graphql_data['group']['workItems']['nodes'] }
  let(:item_filter_params) { {} }
  let(:current_user) { user }
  let(:query_group) { group }

  let(:fields) do
    <<~QUERY
      nodes {
        #{all_graphql_fields_for('workItems'.classify, max_depth: 2)}
      }
    QUERY
  end

  describe 'N + 1 queries' do
    let_it_be(:label1) { create(:group_label, group: group) }
    let_it_be(:label2) { create(:group_label, group: group) }
    let_it_be(:milestone1) { create(:milestone, group: group) }
    let_it_be(:milestone2) { create(:milestone, group: group) }

    let_it_be(:project_work_item) { create(:work_item, project: project) }
    let_it_be(:sub_group_work_item) do
      create(
        :work_item,
        namespace: sub_group,
        author: reporter,
        milestone: milestone1,
        labels: [label1]
      ) do |work_item|
        create(:award_emoji, name: 'star', awardable: work_item)
      end
    end

    let_it_be(:group_work_item) do
      create(
        :work_item,
        :epic_with_legacy_epic,
        namespace: group,
        author: reporter,
        title: 'search_term',
        milestone: milestone2,
        labels: [label2]
      ) do |work_item|
        create(:award_emoji, name: 'star', awardable: work_item)
        create(:award_emoji, name: 'rocket', awardable: work_item.sync_object)
      end
    end

    let_it_be(:confidential_work_item) do
      create(:work_item, :confidential, namespace: group, author: reporter)
    end

    let_it_be(:other_work_item) { create(:work_item) }

    shared_examples 'work items resolver without N + 1 queries' do
      it 'avoids N+1 queries', :use_sql_query_cache do
        post_graphql(query, current_user: current_user) # Warmup

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        expect_graphql_errors_to_be_empty

        create_list(
          :work_item,
          3,
          :epic_with_legacy_epic,
          namespace: group,
          labels: [label1, label2],
          milestone: milestone2,
          author: reporter
        ) do |work_item|
          create(:award_emoji, name: 'eyes', awardable: work_item)
          create(:award_emoji, name: 'rocket', awardable: work_item.sync_object)
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: work_item.sync_object)
        end

        expect do
          post_graphql(query, current_user: current_user)
        end.not_to exceed_all_query_limit(control).with_threshold(1)
        expect_graphql_errors_to_be_empty
      end
    end

    context 'when querying root fields' do
      it_behaves_like 'work items resolver without N + 1 queries'
    end

    # We need a separate example since all_graphql_fields_for will not fetch fields from types
    # that implement the widget interface. Only `type` for the widgets field.
    context 'when querying the widget interface' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      let(:fields) do
        <<~GRAPHQL
          nodes {
            widgets {
              type
              ... on WorkItemWidgetDescription {
                edited
                lastEditedAt
                lastEditedBy {
                  webPath
                  username
                }
                taskCompletionStatus {
                  completedCount
                  count
                }
              }
              ... on WorkItemWidgetAssignees {
                assignees { nodes { id } }
              }
              ... on WorkItemWidgetHierarchy {
                parent { id }
                children {
                  nodes {
                    id
                  }
                }
              }
              ... on WorkItemWidgetLabels {
                labels { nodes { id } }
                allowsScopedLabels
              }
              ... on WorkItemWidgetMilestone {
                milestone {
                  id
                }
              }
              ... on WorkItemWidgetAwardEmoji {
                upvotes
                downvotes
                awardEmoji {
                  nodes {
                    name
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      it_behaves_like 'work items resolver without N + 1 queries'

      context 'when querying for WorkItemWidgetAwardEmoji' do
        it 'queries unified award emojis correctly' do
          post_graphql(query, current_user: current_user)

          data = graphql_data_at(:group, :workItems, :nodes, 0, :widgets)
          data = data.find { |k| k if k['type'] == 'AWARD_EMOJI' }['awardEmoji']['nodes']
          expect(data.flat_map(&:values)).to match_array(%w[star rocket])
        end

        it 'fetches unified upvotes and downvotes' do
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: group_work_item)
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: group_work_item.sync_object)
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: group_work_item.sync_object)
          create(:award_emoji, name: AwardEmoji::THUMBS_DOWN, awardable: group_work_item.sync_object)

          post_graphql(query, current_user: current_user)

          data = graphql_data_at(:group, :workItems, :nodes, 0, :widgets)
          upvotes = data.find { |k| k if k['type'] == 'AWARD_EMOJI' }['upvotes']
          downvotes = data.find { |k| k if k['type'] == 'AWARD_EMOJI' }['downvotes']

          expect(upvotes).to eq(3)
          expect(downvotes).to eq(1)
        end
      end
    end
  end

  context 'when work_item_epics feature flag is disabled' do
    let_it_be(:group_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

    before do
      stub_licensed_features(epics: true)
    end

    context 'when namespace_level_work_items feature flag is enabled' do
      before do
        stub_feature_flags(work_item_epics: false, namespace_level_work_items: true)
      end

      it 'returns namespace level work items' do
        post_graphql(query, current_user: current_user)

        work_items = graphql_data_at(:group, :workItems, :nodes)

        expect(work_items.size).to eq(1)
        expect(work_items[0]['workItemType']['name']).to eq('Epic')
      end
    end

    context 'when namespace_level_work_items feature flag is disabled' do
      before do
        stub_feature_flags(work_item_epics: false, namespace_level_work_items: false)
      end

      it 'does not return namespace level work items' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:group, :workItems)).to be_nil
      end
    end
  end

  describe 'license check' do
    let_it_be(:group_issuables) { create_list(:work_item, 10, :epic, namespace: group) }
    let_it_be(:project_issuables) { create_list(:work_item, 10, :epic, project: project) }

    let(:field_name) { 'workItems' }
    let(:container_name) { 'group' }
    let(:container) { group }
    let(:count_path) { ['data', container_name, field_name, 'count'] }

    context 'with group level work items' do
      context 'with group level work item license' do
        before do
          stub_licensed_features(epics: true)
        end

        it_behaves_like 'issuables pagination and count' do
          let(:issuables) { group_issuables }
        end
      end

      context 'without group level work item license' do
        let(:issuables) { group_issuables }
        let(:page_size) { 20 }

        let(:query) do
          <<~GRAPHQL
            query #{container_name}($fullPath: ID!, $first: Int, $after: String) {
              #{container_name}(fullPath: $fullPath) {
                #{field_name}(first: $first, after: $after) {
                  count
                  edges {
                    node {
                      id
                    }
                  }
                  pageInfo {
                    endCursor
                    hasNextPage
                  }
                }
              }
            }
          GRAPHQL
        end

        subject(:execute) do
          GitlabSchema.execute(
            query,
            context: { current_user: user },
            variables: {
              fullPath: container.full_path,
              first: page_size
            }
          ).to_h
        end

        before do
          stub_licensed_features(epics: false)
        end

        it 'does not return an error' do
          expect(execute['errors']).to be_nil
        end

        it 'does not return work items' do
          data = execute['data'][container_name]['workItems']

          expect(data['edges']).to be_empty
          expect(data['count']).to eq(10)
        end
      end
    end

    context 'with group and project level work items' do
      let(:work_items_query) do
        <<~GRAPHQL
          query #{container_name}($fullPath: ID!, $first: Int, $after: String) {
            #{container_name}(fullPath: $fullPath) {
              #{field_name}(first: $first, after: $after, includeDescendants: true) {
                count
                edges {
                  node {
                    id
                  }
                }
                pageInfo {
                  endCursor
                  hasNextPage
                }
              }
            }
          }
        GRAPHQL
      end

      context 'with group level work item license' do
        before do
          stub_licensed_features(epics: true)
        end

        it_behaves_like 'issuables pagination and count' do
          let_it_be(:issuables) { [group_issuables, project_issuables].flatten }

          let(:per_page) { 19 }
          let(:query) { work_items_query }
        end
      end

      context 'without group level work item license' do
        let_it_be(:issuables) { [group_issuables, project_issuables] }

        let(:page_size) { 20 }
        let(:query) { work_items_query }

        subject(:execute) do
          GitlabSchema.execute(
            query,
            context: { current_user: user },
            variables: {
              fullPath: container.full_path,
              first: page_size
            }
          ).to_h
        end

        before do
          stub_licensed_features(epics: false)
        end

        it 'does not return an error' do
          expect(execute['errors']).to be_nil
        end

        it 'does not return work items' do
          data = execute['data'][container_name]['workItems']

          expect(data['count']).to eq(20)
          expect(data['edges'].count).to eq(10)
          expect(data['edges'].map { |node| node.dig('node', 'id') }).to match_array(
            project_issuables.flat_map(&:to_gid).map(&:to_s)
          )
        end
      end
    end
  end

  def query(params = item_filter_params)
    graphql_query_for(
      'group',
      { 'fullPath' => query_group.full_path },
      query_graphql_field('workItems', params, fields)
    )
  end
end
