# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::QAi::Client, feature_category: :ai_agents do
  let_it_be(:user) { create(:user) }
  let_it_be(:oauth_app) { create(:doorkeeper_application) }

  let(:service_data) { instance_double(CloudConnector::SelfManaged::AvailableServiceData) }

  let(:cc_token) { 'cc_token' }
  let(:response) { 'response' }
  let(:role_arn) { 'role_arn' }
  let(:secret) { 'secret' }
  let(:logger) { instance_double(Gitlab::Llm::Logger) }

  before do
    allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
  end

  describe '#create_event' do
    subject(:create_event) do
      described_class.new(user)
        .create_event(
          payload: {},
          auth_grant: '1234',
          role_arn: '5678'
        )
    end

    let(:status) { 204 }
    let(:body) { nil }
    let(:headers) { { 'Content-Type' => "application/json" } }

    before do
      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/events")
        .with(body: {
          payload: {},
          code: '1234',
          role_arn: '5678'
        }.to_json).to_return(body: body, status: status, headers: headers)
    end

    it 'makes expected HTTP post request' do
      expect(service_data).to receive_messages(
        name: 'amazon_q_integration',
        access_token: 'cc_token'
      )
      expect(::CloudConnector::AvailableServices).to receive(:find_by_name)
        .with(:amazon_q_integration).and_return(service_data)

      expect(logger).to receive(:conditional_info)
        .with(user, a_hash_including(
          message: "Received successful response from AI Gateway",
          ai_component: 'abstraction_layer',
          status: status,
          event_name: 'response_received'))

      response = create_event
      expect(response.code).to eq(204)
      expect(response.body).to be_empty
    end

    context 'with failed response' do
      let(:status) { 500 }
      let(:body) { { detail: "failed request" }.to_json }

      it 'logs a 500 error' do
        expect(logger).to receive(:error)
          .with(a_hash_including(
            message: "Error response from AI Gateway",
            ai_component: 'abstraction_layer',
            status: status,
            body: "failed request"))

        response = create_event
        expect(response.code).to eq(500)
      end
    end
  end

  describe '#perform_create_auth_application' do
    subject(:perform_create_auth_application) do
      described_class.new(user)
        .perform_create_auth_application(oauth_app, secret, role_arn)
    end

    before do
      payload = {
        client_id: oauth_app.uid.to_s,
        client_secret: secret,
        redirect_url: oauth_app.redirect_uri,
        instance_url: Gitlab.config.gitlab.url,
        role_arn: role_arn
      }

      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/oauth/application")
        .with(body: payload.to_json)
        .to_return(body: response)
    end

    it 'makes expected HTTP post request' do
      expect(service_data).to receive_messages(
        name: 'amazon_q_integration',
        access_token: 'cc_token'
      )
      expect(::CloudConnector::AvailableServices).to receive(:find_by_name)
        .with(:amazon_q_integration).and_return(service_data)

      expect(logger).to receive(:conditional_info)
        .with(user, a_hash_including(
          message: "Received successful response from AI Gateway",
          ai_component: 'abstraction_layer',
          status: 200,
          event_name: 'response_received'))

      expect(perform_create_auth_application.parsed_response).to eq(response)
    end
  end
end
