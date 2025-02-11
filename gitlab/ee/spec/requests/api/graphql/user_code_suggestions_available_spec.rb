# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying user code suggestions access',
  :clean_gitlab_redis_cache, feature_category: :code_suggestions do
  include GraphqlHelpers

  let(:fields) do
    <<~GRAPHQL
      duoCodeSuggestionsAvailable
    GRAPHQL
  end

  let(:query) do
    graphql_query_for('currentUser', fields)
  end

  subject(:graphql_response) { graphql_data.dig('currentUser', 'duoCodeSuggestionsAvailable') }

  context 'when user is not logged in' do
    let(:current_user) { nil }

    it 'returns an empty response' do
      post_graphql(query, current_user: current_user)

      expect(graphql_response).to be_nil
    end
  end

  context 'when user is logged in' do
    let_it_be(:current_user) { create(:user) }

    before do
      allow(Ability)
        .to receive(:allowed?).and_call_original

      stub_licensed_features(code_suggestions: true)

      service = instance_double('::CloudConnector::SelfSigned::AvailableServiceData', name: :code_suggestions,
        free_access?: false)
      purchases = class_double(GitlabSubscriptions::AddOnPurchase)
      allow(::CloudConnector::AvailableServices).to receive(:find_by_name).and_return(service)
      allow(service).to receive_message_chain(:add_on_purchases, :assigned_to_user).and_return(purchases)
      allow(purchases).to receive_messages(any?: user_has_add_on_purchases, uniq_namespace_ids: [])
    end

    context 'when user has access to code suggestions' do
      let(:user_has_add_on_purchases) { true }

      it 'returns true' do
        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq(true)
      end

      context 'when feature flag is off' do
        before do
          stub_feature_flags(ai_duo_code_suggestions_switch: false)
        end

        it 'returns false' do
          post_graphql(query, current_user: current_user)

          expect(graphql_response).to eq(false)
        end
      end
    end

    context 'when user does not have access to code suggestions' do
      let(:user_has_add_on_purchases) { false }

      it 'returns false' do
        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq(false)
      end
    end
  end
end
