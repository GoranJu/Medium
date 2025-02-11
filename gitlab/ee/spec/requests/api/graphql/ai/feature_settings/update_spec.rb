# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating an AI Feature setting', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
  let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :vendored, self_hosted_model: nil) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active)
  end

  let(:mutation_name) { :ai_feature_setting_update }
  let(:mutation_params) do
    {
      feature: 'CODE_GENERATIONS',
      provider: 'VENDORED'
    }
  end

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

      context 'when there are ActiveRecord validation errors' do
        let(:mutation_params) do
          {
            feature: 'CODE_GENERATIONS',
            provider: 'SELF_HOSTED'
          }
        end

        it 'returns an error' do
          request

          result = json_response['data']['aiFeatureSettingUpdate']

          expect(result['aiFeatureSetting']).to eq(nil)
          expect(result['errors']).to eq(["Self hosted model can't be blank"])
        end

        it 'does not update the AI feature setting' do
          request

          expect { feature_setting.reload }.not_to change { feature_setting.provider }
        end
      end

      context 'when there are no errors' do
        let(:self_hosted_model_id) { self_hosted_model.to_global_id.to_s }
        let(:mutation_params) do
          {
            feature: 'CODE_GENERATIONS',
            provider: 'SELF_HOSTED',
            ai_self_hosted_model_id: self_hosted_model_id
          }
        end

        context 'when the feature setting exists' do
          it 'updates the feature setting' do
            expect { request }.not_to change { ::Ai::FeatureSetting.count }

            expect(response).to have_gitlab_http_status(:success)

            expect(feature_setting.reload.feature).to eq('code_generations')
            expect(feature_setting.reload.provider).to eq('self_hosted')
            expect(feature_setting.reload.self_hosted_model.to_global_id.to_s).to eq(self_hosted_model_id)
          end
        end

        context 'when the feature setting does not exist' do
          before do
            ::Ai::FeatureSetting.delete_all
          end

          it 'create the feature setting' do
            expect { request }.to change { ::Ai::FeatureSetting.count }.from(0).to(1)

            expect(response).to have_gitlab_http_status(:success)

            created_feature_setting = ::Ai::FeatureSetting.last

            expect(created_feature_setting.feature).to eq('code_generations')
            expect(created_feature_setting.provider).to eq('self_hosted')
            expect(created_feature_setting.self_hosted_model.to_global_id.to_s).to eq(self_hosted_model_id)
          end
        end
      end
    end
  end
end
