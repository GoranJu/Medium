# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::ModelDetails::CodeCompletion, feature_category: :code_suggestions do
  include GitlabSubscriptions::SaasSetAssignmentHelpers

  let_it_be(:user) { create(:user) }
  let(:completions_model_details) { described_class.new(current_user: user) }

  shared_examples 'selects the correct model' do
    context 'when Fireworks/Qwen beta FF is enabled' do
      before do
        stub_feature_flags(fireworks_qwen_code_completion: true)
        stub_feature_flags(code_completion_model_opt_out_from_fireworks_qwen: false)
      end

      context 'on GitLab self-managed' do
        before do
          allow(Gitlab).to receive(:org_or_com?).and_return(false)
        end

        it 'returns the fireworks/qwen model' do
          expect(actual_result).to eq(expected_fireworks_result)
        end

        context 'when opted out of Fireworks/Qwen through the ops FF' do
          it 'returns the codegecko model' do
            stub_feature_flags(code_completion_model_opt_out_from_fireworks_qwen: true)

            expect(actual_result).to eq(expected_codegecko_result)
          end
        end
      end

      context 'on GitLab saas' do
        before do
          allow(Gitlab).to receive(:org_or_com?).and_return(true)
        end

        let_it_be(:group1) do
          create(:group).tap do |g|
            setup_addon_purchase_and_seat_assignment(user, g, :code_suggestions)
          end
        end

        let_it_be(:group2) do
          create(:group).tap do |g|
            setup_addon_purchase_and_seat_assignment(user, g, :duo_enterprise)
          end
        end

        it 'returns the fireworks/qwen model' do
          expect(actual_result).to eq(expected_fireworks_result)
        end

        context "when one of user's root groups has opted out of Fireworks/Qwen through the ops FF" do
          before do
            # opt out for group2
            stub_feature_flags(code_completion_model_opt_out_from_fireworks_qwen: group2)
          end

          it 'returns the code gecko model' do
            expect(actual_result).to eq(expected_codegecko_result)
          end
        end

        describe 'executed queries' do
          it 'executes the expected number of queries' do
            # We are only expecting 3 queries:
            # 1 - for ModelDetails::Completions#feature_setting
            # 2 - for current_user#duo_available_namespace_ids in ModelDetails::Completions#user_duo_groups
            # 3 - for Group.by_id(<group ids>) in ModelDetails::Completions#user_duo_groups
            expect { actual_result }.not_to exceed_query_limit(3)
          end
        end
      end
    end

    context 'when Fireworks/Qwen beta FF is disabled' do
      before do
        stub_feature_flags(fireworks_qwen_code_completion: false)
      end

      it 'returns the codegecko model' do
        expect(actual_result).to eq(expected_codegecko_result)
      end
    end

    context 'when code_completions is self-hosted' do
      before do
        feature_setting_double = instance_double(::Ai::FeatureSetting, self_hosted?: true)
        allow(::Ai::FeatureSetting).to receive(:find_by_feature).with('code_completions')
          .and_return(feature_setting_double)
      end

      it 'returns the self-hosted model' do
        expect(actual_result).to eq(expected_self_hosted_model_result)
      end
    end
  end

  describe '#current_model' do
    it_behaves_like 'selects the correct model' do
      subject(:actual_result) { completions_model_details.current_model }

      let(:expected_fireworks_result) do
        {
          model_provider: 'fireworks_ai',
          model_name: 'qwen2p5-coder-7b'
        }
      end

      let(:expected_codegecko_result) { {} }

      let(:expected_self_hosted_model_result) { {} }
    end
  end

  describe '#saas_primary_model_class' do
    it_behaves_like 'selects the correct model' do
      subject(:actual_result) { completions_model_details.saas_primary_model_class }

      let(:expected_fireworks_result) do
        CodeSuggestions::Prompts::CodeCompletion::FireworksQwen
      end

      let(:expected_codegecko_result) do
        CodeSuggestions::Prompts::CodeCompletion::VertexAi
      end

      let(:expected_self_hosted_model_result) { nil }
    end
  end
end
