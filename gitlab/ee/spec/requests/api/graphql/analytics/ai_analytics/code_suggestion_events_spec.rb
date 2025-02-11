# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Group|Project).aiUsageData.codeSuggestionEvents', :click_house, feature_category: :code_suggestions do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, name: 'my-group') }
  let_it_be(:subgroup) { create(:group, parent: group, name: 'my-subgroup') }
  let_it_be(:group_project) { create(:project, group: group) }
  let_it_be(:subgroup_project) { create(:project, group: group) }
  let_it_be(:other_group_project) { create(:project) }
  let_it_be(:current_user) { create(:user, :with_self_managed_duo_enterprise_seat, :with_namespace) }
  let_it_be(:user_1) { create(:user, :with_namespace) }
  let_it_be(:user_2) { create(:user, :with_namespace) }
  let_it_be(:user_3) { create(:user, :with_namespace) }

  let(:ai_usage_data_fields) do
    nodes = <<~NODES
      nodes {
        user {
          id
        }
        id
        event
        language
        suggestionSize
        uniqueTrackingId
        timestamp
      }
    NODES

    code_suggestion_fields =
      query_graphql_field(:code_suggestion_events, {}, nodes)

    query_graphql_field(:aiUsageData, filter_params, code_suggestion_fields)
  end

  let(:filter_params) { {} }
  let(:expected_filters) { {} }

  let_it_be(:code_suggestion_event_1) { create(:code_suggestion_event, :shown, user: user_1) }
  let_it_be(:code_suggestion_event_2) { create(:code_suggestion_event, :accepted, user: user_1) }
  let_it_be(:code_suggestion_event_3) { create(:code_suggestion_event, :accepted, user: user_2) }
  let_it_be(:code_suggestion_event_4) { create(:code_suggestion_event, :accepted, user: user_3) }

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)

    insert_events_into_click_house([
      build_stubbed(:event, :pushed, project: group_project, author: user_1),
      build_stubbed(:event, :pushed, project: group_project, author: user_1),
      build_stubbed(:event, :pushed, project: subgroup_project, author: user_2),
      build_stubbed(:event, :pushed, project: other_group_project, author: user_3)
    ])
  end

  shared_examples 'code suggestion events' do
    context 'when user cannot read code suggestion events' do
      before_all do
        group.add_guest(current_user)
      end

      it 'renders error' do
        post_graphql(query, current_user: current_user)

        expect(code_suggestion_events).to be_nil
      end
    end

    context 'when user can read code suggestion events' do
      before_all do
        group.add_reporter(current_user)
      end

      it 'returns code suggestion events from contributors' do
        post_graphql(query, current_user: current_user)

        event_ids = code_suggestion_events.pluck('id')

        expect(code_suggestion_events.count).to eq(3)
        expect(event_ids).to match_array([code_suggestion_event_1.to_global_id.to_s,
          code_suggestion_event_2.to_global_id.to_s, code_suggestion_event_3.to_global_id.to_s])
      end
    end
  end

  context 'for group' do
    it_behaves_like 'code suggestion events' do
      let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_usage_data_fields) }
      let(:code_suggestion_events) { graphql_data.dig('group', 'aiUsageData', 'codeSuggestionEvents', 'nodes') }
    end

    # This context can be removed within next iterations after
    # we allow filtering events by groups or projects
    context 'when group is not a root group' do
      let(:query) { graphql_query_for(:group, { fullPath: subgroup.full_path }, ai_usage_data_fields) }

      before_all do
        group.add_reporter(current_user)
      end

      it 'raises error' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to include(a_hash_including('message' => 'Not available for this resource.'))
      end
    end
  end

  context 'for project' do
    let(:query) { graphql_query_for(:project, { fullPath: group_project.full_path }, ai_usage_data_fields) }
    let(:code_suggestion_events) { graphql_data.dig('project', 'aiUsageData', 'codeSuggestionEvents', 'nodes') }

    context 'when user has right permissions' do
      before_all do
        group.add_reporter(current_user)
      end

      # This example can be removed within next iterations after
      # we allow filtering events by groups or projects
      it 'raises an exception' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to include(a_hash_including('message' => 'Not available for this resource.'))
      end
    end
  end
end
