# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe, feature_category: :cloud_connector do
  let(:probe) { described_class.new }
  let(:url) { 'https://ai-gateway.example.com' }
  let(:ai_setting) { Ai::Setting.instance }

  describe '#execute' do
    context 'when AI_GATEWAY_URL is set' do
      before do
        stub_env('AI_GATEWAY_URL', url)
      end

      it 'returns a successful result' do
        result = probe.execute
        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be(true)
        expect(result.message).to match(%r{Self hosted AI Gateway URL is set to #{url}})
      end
    end

    context 'when AI_GATEWAY_URL is not set' do
      before do
        stub_env('AI_GATEWAY_URL', nil)
      end

      it 'returns a failed result' do
        result = probe.execute
        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be(false)
        expect(result.message).to match(%r{Self hosted AI Gateway URL is not set.})
      end

      context 'when ai_gateway_url is set' do
        before do
          ai_setting.update!(ai_gateway_url: url)
        end

        it 'returns a successful result' do
          result = probe.execute
          expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
          expect(result.success?).to be(true)
          expect(result.message).to match(%r{Self hosted AI Gateway URL is set to #{url}})
        end
      end
    end
  end
end
