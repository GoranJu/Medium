# frozen_string_literal: true

require 'spec_helper'
require_relative 'probes/test_probe'

RSpec.describe CloudConnector::StatusChecks::StatusService, feature_category: :cloud_connector do
  let(:succeeded_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: true) }
  let(:failed_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: false) }
  let(:user) { build(:user) }

  subject(:service) { described_class.new(user: user, probes: probes) }

  describe '#initialize' do
    subject(:service) { described_class.new(user: user) }

    context 'when no probes are passed' do
      it 'creates default probes' do
        service_probes = service.probes

        expect(service_probes.count).to eq(6)
        expect(service_probes[0]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::LicenseProbe)
        expect(service_probes[1]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe)
        expect(service_probes[2]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe)
        expect(service_probes[3]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::AccessProbe)
        expect(service_probes[4]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::TokenProbe)
        expect(service_probes[5]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe)
      end
    end

    context 'when self-hosted AI Gateway is required' do
      before do
        allow(::Gitlab::Ai::SelfHosted::AiGateway).to receive(:required?).and_return(true)
      end

      it 'uses a different set of probes' do
        service_probes = service.probes

        expect(service_probes.count).to eq(3)
        expect(service_probes[0]).to be_an_instance_of(
          CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe
        )
        expect(service_probes[1]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe)
        expect(service_probes[2]).to be_an_instance_of(
          CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe
        )
      end
    end

    context 'when CLOUD_CONNECTOR_SELF_SIGN_TOKENS is set' do
      let(:ai_gateway_url) { 'http://localhost:5002' }
      let(:local_host_probe) { instance_double(CloudConnector::StatusChecks::Probes::HostProbe) }

      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', 'true')

        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return(ai_gateway_url)
      end

      it 'uses a different set of probes' do
        expect(CloudConnector::StatusChecks::Probes::HostProbe).to(
          receive(:new).with(ai_gateway_url).and_return(local_host_probe)
        )

        service_probes = service.probes

        expect(service_probes.count).to eq(2)
        expect(service_probes[0]).to be(local_host_probe)
        expect(service_probes[1]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe)
      end
    end
  end

  describe '#execute' do
    context 'when all probes succeed' do
      let(:probes) { [succeeded_probe, succeeded_probe] }

      it 'executes all probes and returns successful status result' do
        expect(succeeded_probe).to receive(:execute).twice.and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be true
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to be_nil
      end
    end

    context 'when any probe fails' do
      let(:probes) { [succeeded_probe, failed_probe] }

      it 'executes all probes and returns unsuccessful status result' do
        expect(succeeded_probe).to receive(:execute).and_call_original
        expect(failed_probe).to receive(:execute).and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to eq('Some probes failed')
      end
    end

    context 'when all probes fail' do
      let(:probes) { [failed_probe, failed_probe] }

      it 'executes all probes and returns unsuccessful status result' do
        expect(failed_probe).to receive(:execute).twice.and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to eq('Some probes failed')
      end
    end
  end
end
