# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating an AI Feature setting', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:duo_settings) { create(:ai_settings) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active)
  end

  let(:mutation_name) { :duo_settings_update }
  let(:mutation_params) { { ai_gateway_url: "http://new-ai-gateway-url" } }

  let(:mutation) { graphql_mutation(mutation_name, mutation_params) }

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  describe '#resolve' do
    context 'when the user does not have write access' do
      let(:current_user) { create(:user) }

      it_behaves_like 'performs the right authorization'
      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when the user has write access' do
      it_behaves_like 'performs the right authorization'

      context 'when there are errors' do
        let(:mutation_params) { { ai_gateway_url: "foobar" } }

        it 'returns an error' do
          request

          result = json_response['data']['duoSettingsUpdate']
          expect(result['errors']).to match_array(
            ["Ai gateway url is not allowed: Only allowed schemes are http, https"]
          )

          expect { duo_settings.reload }.not_to change { duo_settings.ai_gateway_url }
        end

        it 'returns the existing ai gateway url' do
          request

          result = json_response['data']['duoSettingsUpdate']
          expect(result['aiGatewayUrl']).to eq('http://0.0.0.0:5052')
        end
      end

      context 'when there are no errors' do
        it 'updates Duo settings' do
          request

          result = json_response['data']['duoSettingsUpdate']

          expect(result).to include("aiGatewayUrl" => "http://new-ai-gateway-url")
          expect(result['errors']).to eq([])

          expect { duo_settings.reload }.to change { duo_settings.ai_gateway_url }.to("http://new-ai-gateway-url")
        end
      end
    end
  end
end
