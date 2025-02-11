# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying user available features', :clean_gitlab_redis_cache, feature_category: :duo_chat do
  include GraphqlHelpers

  let(:fields) do
    <<~GRAPHQL
      duoChatAvailableFeatures
    GRAPHQL
  end

  let(:query) do
    graphql_query_for('currentUser', fields)
  end

  subject(:graphql_response) { graphql_data.dig('currentUser', 'duoChatAvailableFeatures') }

  context 'when user is not logged in' do
    let(:current_user) { nil }

    it 'returns an empty response' do
      post_graphql(query, current_user: current_user)

      expect(graphql_response).to be_nil
    end
  end

  context 'when user is logged in' do
    let_it_be(:current_user) { create(:user) }
    let(:service) { instance_double(::CloudConnector::BaseAvailableServiceData, name: :any_name) }
    let(:service_not_available) { instance_double(::CloudConnector::BaseAvailableServiceData, name: :any_name) }

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(:user, :allowed?).and_return(true)

      allow(::CloudConnector::AvailableServices).to receive(:find_by_name).and_return(service_not_available)
      allow(service_not_available).to receive_message_chain(:add_on_purchases, :assigned_to_user, :any?)
        .and_return(false)
      allow(service_not_available).to receive_messages({ free_access?: false })

      purchases = class_double(GitlabSubscriptions::AddOnPurchase)

      allow(::CloudConnector::AvailableServices).to receive(:find_by_name).with(:include_file_context)
        .and_return(service)
      allow(::CloudConnector::AvailableServices).to receive(:find_by_name).with(:include_merge_request_context)
        .and_return(service)
      allow(service).to receive_message_chain(:add_on_purchases, :assigned_to_user).and_return(purchases)
      allow(purchases).to receive_messages(any?: true, uniq_namespace_ids: [])
    end

    it 'returns a list of available features' do
      post_graphql(query, current_user: current_user)

      expect(graphql_response).to eq(%w[include_file_context include_merge_request_context])
    end

    context 'when ai_duo_chat_switch feature flag is off' do
      before do
        stub_feature_flags(ai_duo_chat_switch: false)
      end

      it 'returns an empty response' do
        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq([])
      end
    end

    context 'when user does not have access to chat' do
      before do
        allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(:user, :allowed?).and_return(false)
      end

      it 'returns an empty response' do
        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq([])
      end
    end
  end
end
