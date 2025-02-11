# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a work item list for a project', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:current_user) { create(:user) }

  let(:items_data) { graphql_data['project']['workItems']['edges'] }
  let(:item_ids) { graphql_dig_at(items_data, :node, :id) }
  let(:item_filter_params) { {} }

  let(:fields) do
    <<~QUERY
    edges {
      node {
        #{all_graphql_fields_for('workItems'.classify)}
      }
    }
    QUERY
  end

  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('workItems', item_filter_params, fields)
    )
  end

  describe 'work items with widgets' do
    let(:widgets_data) { graphql_dig_at(items_data, :node, :widgets) }

    context 'with status widget' do
      let_it_be(:work_item1) { create(:work_item, :satisfied_status, project: project) }
      let_it_be(:work_item2) { create(:work_item, :failed_status, project: project) }
      let_it_be(:work_item3) { create(:work_item, :requirement, project: project) }

      let(:fields) do
        <<~QUERY
        edges {
          node {
            id
            widgets {
              type
              ... on WorkItemWidgetStatus {
                status
              }
            }
          }
        }
        QUERY
      end

      before do
        stub_licensed_features(requirements: true, okrs: true)
      end

      it 'returns work items including status', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(item_ids).to contain_exactly(
          work_item1.to_global_id.to_s,
          work_item2.to_global_id.to_s,
          work_item3.to_global_id.to_s
        )
        expect(widgets_data).to include(
          a_hash_including('status' => 'satisfied'),
          a_hash_including('status' => 'failed'),
          a_hash_including('status' => 'unverified')
        )
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create_list(:work_item, 3, :satisfied_status, project: project)

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
      end

      context 'when filtering' do
        context 'with status widget' do
          let(:item_filter_params) { 'statusWidget: { status: FAILED }' }

          it 'filters by status argument' do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(item_ids).to contain_exactly(work_item2.to_global_id.to_s)
          end
        end
      end
    end

    context 'with legacy requirement widget' do
      let_it_be(:work_item1) { create(:work_item, :requirement, project: project) }
      let_it_be(:work_item2) { create(:work_item, :requirement, project: project) }
      let_it_be(:work_item3) { create(:work_item, :requirement, project: project) }
      let_it_be(:work_item3_different_project) { create(:work_item, :requirement, iid: work_item3.iid) }

      let(:fields) do
        <<~QUERY
        edges {
          node {
            id
            widgets {
              type
              ... on WorkItemWidgetRequirementLegacy {
                legacyIid
              }
            }
          }
        }
        QUERY
      end

      before do
        stub_licensed_features(requirements: true)
      end

      it 'returns work items including legacy iid', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(item_ids).to contain_exactly(
          work_item1.to_global_id.to_s,
          work_item2.to_global_id.to_s,
          work_item3.to_global_id.to_s
        )

        expect(widgets_data).to include(
          a_hash_including('legacyIid' => work_item1.requirement.iid),
          a_hash_including('legacyIid' => work_item2.requirement.iid),
          a_hash_including('legacyIid' => work_item3.requirement.iid)
        )
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create_list(:work_item, 3, :requirement, project: project)

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
      end

      context 'when filtering' do
        context 'with legacy requirement widget' do
          let(:item_filter_params) { "requirementLegacyWidget: { legacyIids: [\"#{work_item2.requirement.iid}\"] }" }

          it 'filters by legacy IID argument' do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(item_ids).to contain_exactly(work_item2.to_global_id.to_s)
          end
        end
      end
    end

    context 'with progress widget' do
      let_it_be(:work_item1) { create(:work_item, :objective, project: project) }
      let_it_be(:progress) { create(:progress, work_item: work_item1) }

      let(:fields) do
        <<~QUERY
        edges {
          node {
            id
            widgets {
              type
              ... on WorkItemWidgetProgress {
                progress
                updatedAt
                currentValue
                startValue
                endValue
              }
            }
          }
        }
        QUERY
      end

      before do
        stub_licensed_features(okrs: true)
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create_list(:work_item, 3, :objective, project: project)

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
      end
    end

    context 'with test reports widget' do
      let_it_be(:requirement_work_item_1) { create(:work_item, :requirement, project: project) }
      let_it_be(:test_report) { create(:test_report, requirement_issue: requirement_work_item_1) }

      let(:fields) do
        <<~GRAPHQL
          edges {
            node {
              id
              widgets {
                type
                ... on WorkItemWidgetTestReports {
                  testReports {
                    nodes {
                      id
                      author {
                        username
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      before do
        stub_licensed_features(requirements: true)
      end

      it 'avoids N+1 queries' do
        post_graphql(query, current_user: current_user) # warmup

        control = ActiveRecord::QueryRecorder.new do
          post_graphql(query, current_user: current_user)
        end

        requirement_work_item_2 = create(:work_item, :requirement, project: project)
        create(:test_report, requirement_issue: requirement_work_item_2)

        expect { post_graphql(query, current_user: current_user) }
          .not_to exceed_query_limit(control)
      end
    end

    context 'with development widget' do
      let_it_be(:work_item) { create(:work_item, project: project) }

      context 'for the feature flags field' do
        before_all do
          2.times do
            create_feature_flag_for(work_item)
          end
        end

        let(:fields) do
          <<~GRAPHQL
            nodes {
              id
              widgets {
                type
                ... on WorkItemWidgetDevelopment {
                  featureFlags {
                    nodes {
                      id
                      name
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        it 'avoids N+1 queries' do
          post_graphql(query, current_user: current_user) # warmup

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            post_graphql(query, current_user: current_user)
          end

          2.times do
            new_work_item = create(:work_item, project: project)
            create_feature_flag_for(new_work_item)
          end

          expect { post_graphql(query, current_user: current_user) }
            .to issue_same_number_of_queries_as(control)
        end
      end
    end

    context 'with iteration widget' do
      let_it_be(:iteration_cadence) { create(:iterations_cadence, group: project.group) }
      let_it_be(:iteration) { create(:iteration, iterations_cadence: iteration_cadence) }
      let_it_be(:work_item1) { create(:work_item, :issue, project: project, iteration: iteration) }

      let(:fields) do
        <<~QUERY
        edges {
          node {
            widgets {
              ... on WorkItemWidgetIteration {
                iteration {
                  id
                  iterationCadence {
                    title
                  }
                }
              }
            }
          }
        }
        QUERY
      end

      before do
        stub_licensed_features(iterations: true)
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        post_graphql(query, current_user: current_user) # warmup

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create_list(:iterations_cadence, 3, group: project.group) do |cadence|
          iteration = create(:iteration, iterations_cadence: cadence)
          create(:work_item, :issue, project: project, iteration: iteration)
        end

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
        expect(response).to have_gitlab_http_status(:success)
      end
    end
  end

  context 'with top level filters' do
    let_it_be(:now) { Time.current }

    let_it_be(:past_work_item) do
      create(:work_item, project: project, created_at: 1.day.ago, due_date: 1.day.ago, closed_at: 1.day.ago,
        updated_at: 1.day.ago)
    end

    let_it_be(:current_work_item) do
      create(:work_item, project: project, created_at: now, updated_at: now, closed_at: now, due_date: now)
    end

    shared_examples 'filters work items by date' do |field_name|
      context "with #{field_name}_before filter" do
        let(:item_filter_params) { "#{field_name.camelize(:lower)}Before: \"#{now.iso8601}\"" }

        it "filters work items by #{field_name} before" do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(item_ids).to contain_exactly(past_work_item.to_global_id.to_s)
        end
      end

      context "with #{field_name}_after filter" do
        let(:item_filter_params) { "#{field_name.camelize(:lower)}After: \"#{(now - 1).iso8601}\"" }

        it "filters work items by #{field_name} after" do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(item_ids).to contain_exactly(current_work_item.to_global_id.to_s)
        end
      end
    end

    %w[created updated due closed].each do |field|
      it_behaves_like 'filters work items by date', field
    end
  end

  def create_feature_flag_for(work_item)
    feature_flag = create(:operations_feature_flag, project: project)
    create(:feature_flag_issue, issue_id: work_item.id, feature_flag: feature_flag)
  end
end
