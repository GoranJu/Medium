# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflow::DuoWorkflowService::Client, feature_category: :duo_workflow do
  let_it_be(:current_user) { create(:user) }
  let(:duo_workflow_service_url) { 'example.com:443' }
  let(:secure) { true }
  let(:stub) { instance_double('DuoWorkflowService::DuoWorkflow::Stub') }
  let(:request) { instance_double('DuoWorkflowService::GenerateTokenRequest') }
  let(:response) { double(token: 'a user jwt', expiresAt: 'a timestamp') } # rubocop:disable RSpec/VerifiedDoubles -- instance_double keeps raising error  the DuoWorkflowService::GenerateTokenResponse class does not implement the class method: token
  let(:channel_credentials) { instance_of(GRPC::Core::ChannelCredentials) }
  let(:cloud_connector_service_data_double) { instance_of(CloudConnector::SelfSigned::AvailableServiceData) }

  subject(:client) do
    described_class.new(
      duo_workflow_service_url: duo_workflow_service_url,
      current_user: current_user,
      secure: secure
    )
  end

  before do
    allow(CloudConnector::AvailableServices).to receive(:find_by_name).with(:duo_workflow).and_return(
      cloud_connector_service_data_double
    )
    allow(cloud_connector_service_data_double).to receive(:access_token).and_return('instance jwt')
    allow(DuoWorkflowService::DuoWorkflow::Stub).to receive(:new).with(anything, channel_credentials).and_return(stub)
    allow(stub).to receive(:generate_token).and_return(response)
    allow(DuoWorkflowService::GenerateTokenRequest).to receive(:new).and_return(request)
  end

  describe '#generate_token' do
    it 'sends the correct metadata hash' do
      client.generate_token

      expect(stub).to have_received(:generate_token).with(
        request,
        metadata: {
          "authorization" => "Bearer instance jwt",
          "x-gitlab-authentication-type" => "oidc",
          'x-gitlab-instance-id' => ::Gitlab::GlobalAnonymousId.instance_id,
          'x-gitlab-realm' => ::CloudConnector.gitlab_realm,
          'x-gitlab-global-user-id' => ::Gitlab::GlobalAnonymousId.user_id(current_user)
        }
      )
    end

    it 'returns a success ServiceResponse with token and expires_at' do
      result = client.generate_token

      expect(result).to be_success
      expect(result.message).to eq('JWT Generated')
      expect(result.payload[:token]).to eq('a user jwt')
      expect(result.payload[:expires_at]).to eq('a timestamp')
    end

    context 'when secure is false' do
      let(:secure) { false }
      let(:channel_credentials) { :this_channel_is_insecure }

      it 'calls with insecure channel credentials' do
        result = client.generate_token

        expect(result).to be_success
      end
    end

    context 'when an error occurs' do
      before do
        allow(stub).to receive(:generate_token).and_raise(StandardError.new('Test error'))
      end

      it 'returns an error ServiceResponse' do
        result = client.generate_token

        expect(result).to be_error
        expect(result.message).to eq('Test error')
      end
    end
  end
end
