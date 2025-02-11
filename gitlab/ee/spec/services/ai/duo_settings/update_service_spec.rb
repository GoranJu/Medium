# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoSettings::UpdateService, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }
  let_it_be(:duo_settings) { create(:ai_settings) }

  let(:params) { { ai_gateway_url: "http://new-ai-gateway-url" } }

  subject(:service_result) { described_class.new(params).execute }

  describe '#execute' do
    context 'when update succeeds' do
      it 'returns a success response' do
        expect { service_result }.to change { duo_settings.reload.ai_gateway_url }.to("http://new-ai-gateway-url")

        expect(service_result).to be_success
        expect(service_result.payload).to eq(duo_settings)
      end
    end

    context 'when update fails' do
      let(:params) { { ai_gateway_url: 'invalid-url' } }

      it 'returns an error response' do
        expect { service_result }.not_to change { duo_settings.reload.ai_gateway_url }

        expect(service_result).to be_error
        expect(service_result.errors).to match_array(
          ["Ai gateway url is not allowed: Only allowed schemes are http, https"]
        )
      end
    end
  end
end
