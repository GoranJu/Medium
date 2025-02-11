# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GitLab Duo settings.', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:duo_settings) { create(:ai_settings) }

  let(:query) do
    %(
      query getDuoSettings {
        duoSettings {
          aiGatewayUrl
        }
      }
    )
  end

  let(:duo_settings_data) { graphql_data_at(:duoSettings) }

  context "when the user is authorized" do
    let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
    let_it_be(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active)
    end

    it 'returns the expected response' do
      post_graphql(query, current_user: current_user)

      expect(duo_settings_data).to eq({ "aiGatewayUrl" => 'http://0.0.0.0:5052' })
    end
  end

  context "when the user is not authorized" do
    it 'does not return GitLab Duo settings' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data['duoSettings']).to be_nil
    end
  end
end
