# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Code suggestions', :api, :js, :requires_custom_models_setup,
  feature_category: :"self-hosted_models", quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/502971' do
  include_context 'file upload requests helpers'

  let(:service) { instance_double('::CloudConnector::SelfSigned::AvailableServiceData') }
  let(:api_path) { "/code_suggestions/completions" }
  let(:url) { capybara_url(api(api_path)) }

  let(:content_above_cursor) do
    <<~CONTENT_ABOVE_CURSOR
      def add(x, y):
        return x + y

      def sub(x, y):
        return x - y

      def multiple(x, y):
        return x * y

      def divide(x, y):
        return x / y

      def is_even(n: int) ->
    CONTENT_ABOVE_CURSOR
  end

  let(:body) do
    {
      current_file: {
        file_name: 'test.py',
        content_above_cursor: content_above_cursor,
        content_below_cursor: ''
      },
      stream: false
    }
  end

  let!(:authorized_user) { create(:user) }

  let!(:personal_access_token) do
    create(:personal_access_token, scopes: %w[ai_features], user: authorized_user)
  end

  let!(:self_hosted_model) do
    create(:ai_self_hosted_model, name: 'codestral', model: :codestral, endpoint: ENV['LITELLM_PROXY_URL'])
  end

  subject(:post_api) do
    HTTParty.post(
      url,
      headers: { "Authorization" => "Bearer #{personal_access_token.token}", content_type: 'application/json' },
      body: body
    )
  end

  before do
    allow(Gitlab).to receive(:com?).and_return(false)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(authorized_user, :access_code_suggestions, :global)
                                        .and_return(true)
    allow(Gitlab::ApplicationRateLimiter).to receive(:threshold).and_return(0)
    allow(::CloudConnector::AvailableServices).to receive(:find_by_name).and_return(service)
    allow(service).to receive_messages(access_token: 'token', name: 'code_suggestions')
    allow(service).to receive_message_chain(:add_on_purchases, :assigned_to_user, :any?).and_return(true)
    allow(service).to receive_message_chain(:add_on_purchases, :assigned_to_user, :uniq_namespace_ids)
      .and_return([1, 2])
  end

  shared_examples 'a code suggestion response' do
    it 'includes the right (mock) response from the LLM' do
      response = post_api
      expect(response.body).to include('Mock response from codestral')
    end
  end

  context 'when code generation' do
    let!(:ai_feature_setting) do
      create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :code_generations)
    end

    let(:body) do
      {
        current_file: {
          file_name: 'test.py',
          content_above_cursor: '# generate a http server',
          content_below_cursor: ''
        },
        intent: 'generation',
        stream: false
      }
    end

    it_behaves_like 'a code suggestion response'
  end

  context 'when code completion' do
    let!(:ai_feature_setting) do
      create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :code_completions)
    end

    let(:prefix) do
      <<~PREFIX
        def is_even(n: int) ->
      PREFIX
    end

    let(:body) do
      {
        current_file: {
          file_name: 'test.py',
          content_above_cursor: prefix,
          content_below_cursor: ''
        },
        intent: 'completion',
        stream: false
      }
    end

    it_behaves_like 'a code suggestion response'
  end
end
