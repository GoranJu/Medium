# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::DuoCodeReview, feature_category: :code_review_workflow do
  let_it_be(:authorized_user) { create(:user) }
  let_it_be(:unauthorized_user) { build(:user) }

  let_it_be(:tokens) do
    {
      api: create(:personal_access_token, scopes: %w[api], user: authorized_user),
      read_api: create(:personal_access_token, scopes: %w[read_api], user: authorized_user),
      ai_features: create(:personal_access_token, scopes: %w[ai_features], user: authorized_user)
    }
  end

  describe 'POST /duo_code_review/evaluations' do
    let(:dev_or_test_env?) { true }
    let(:license_feature_available) { true }
    let(:global_feature_flag_enabled) { true }
    let(:feature_flag_enabled) { true }
    let(:current_user) { authorized_user }
    let(:new_path) { 'path.md' }
    let(:diff) { 'Diff' }
    let(:hunk) { 'Hunk' }
    let(:headers) { {} }

    let(:body) do
      {
        new_path: new_path,
        diff: diff,
        hunk: hunk
      }
    end

    let(:review_prompt) { { messages: ['prompt'] } }
    let(:review_response) { { content: [{ text: 'Review response' }] } }

    subject(:post_api) do
      post api('/duo_code_review/evaluations', current_user), headers: headers, params: body
    end

    before do
      stub_licensed_features(ai_review_mr: license_feature_available)
      stub_feature_flags(ai_global_switch: global_feature_flag_enabled)
      stub_feature_flags(ai_review_merge_request: feature_flag_enabled)

      allow(Gitlab).to receive(:dev_or_test_env?).and_return(dev_or_test_env?)

      allow_next_instance_of(
        ::Gitlab::Llm::Templates::ReviewMergeRequest,
        new_path,
        diff,
        hunk
      ) do |prompt|
        allow(prompt).to receive(:to_prompt).and_return(review_prompt)
      end

      allow_next_instance_of(
        ::Gitlab::Llm::Anthropic::Client,
        authorized_user,
        unit_primitive: 'review_merge_request'
      ) do |client|
        allow(client)
          .to receive(:messages_complete)
          .with(review_prompt)
          .and_return(review_response)
      end

      post_api
    end

    it 'returns 201 with the review response' do
      expect(response).to have_gitlab_http_status(:created)
      expect(response.body).to eq({ review: 'Review response' }.to_json)
    end

    context 'when environment is not development or test' do
      let(:dev_or_test_env?) { false }

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end

    context 'when user is not authenticated' do
      let(:current_user) { nil }

      it { expect(response).to have_gitlab_http_status(:unauthorized) }
    end

    context 'when feature is not available in license' do
      let(:license_feature_available) { false }

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end

    context 'when ai_review_merge_request is disabled' do
      let(:feature_flag_enabled) { false }

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end

    context 'when token is used' do
      let(:current_user) { nil }
      let(:access_token) { tokens[:api] }
      let(:headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

      it { expect(response).to have_gitlab_http_status(:created) }

      context 'when using token with :ai_features scope' do
        let(:access_token) { tokens[:ai_features] }

        it { expect(response).to have_gitlab_http_status(:created) }
      end

      context 'when using token with :read_api scope' do
        let(:access_token) { tokens[:read_api] }

        it { expect(response).to have_gitlab_http_status(:forbidden) }
      end
    end
  end
end
