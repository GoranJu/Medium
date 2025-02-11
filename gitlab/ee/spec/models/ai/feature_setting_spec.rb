# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureSetting, feature_category: :"self-hosted_models" do
  subject { build(:ai_feature_setting) }

  it { is_expected.to belong_to(:self_hosted_model) }
  it { is_expected.to validate_presence_of(:feature) }
  it { is_expected.to validate_uniqueness_of(:feature).ignoring_case_sensitivity }
  it { is_expected.to validate_presence_of(:provider) }

  context 'when feature setting is self hosted' do
    let(:feature_setting) { build(:ai_feature_setting) }

    it { expect(feature_setting).to validate_presence_of(:self_hosted_model) }
    it { expect(feature_setting.provider_title).to eq('Self-hosted model (mistral-7b-ollama-api)') }
  end

  context 'when feature setting is vendored' do
    let(:feature_setting) { build(:ai_feature_setting, provider: :vendored) }

    it { expect(feature_setting.provider_title).to eq('AI vendor') }
  end

  context 'when feature setting is disabled' do
    let(:feature_setting) { build(:ai_feature_setting, provider: :disabled) }

    it { expect(feature_setting.provider_title).to eq('Disabled') }
  end

  describe '.code_suggestions_self_hosted?' do
    where(:feature, :provider, :code_suggestions_self_hosted) do
      [
        [:code_generations, :self_hosted, true],
        [:code_generations, :vendored, false],
        [:code_completions, :self_hosted, true],
        [:code_generations, :vendored, false],
        [:duo_chat, :self_hosted, false]
      ]
    end

    with_them do
      it 'returns whether code generations or completions are self hosted' do
        feature_setting = build(:ai_feature_setting, feature: feature, provider: provider)
        allow(feature_setting).to receive(:compatible_llms).and_return(%w[mistral]) # skip model compatibility check
        feature_setting.save!

        expect(described_class.code_suggestions_self_hosted?).to eq(code_suggestions_self_hosted)
      end
    end
  end

  describe '.for_self_hosted_model' do
    let_it_be(:self_hosted_model) do
      create(:ai_self_hosted_model, name: 'model', model: :mistral)
    end

    let_it_be(:feature_setting) do
      create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :code_completions,
        provider: :self_hosted)
    end

    let_it_be(:other_self_hosted_model) do
      create(:ai_self_hosted_model, name: 'other_model', model: :codegemma)
    end

    let_it_be(:other_feature_setting) do
      create(:ai_feature_setting, self_hosted_model: other_self_hosted_model, feature: :code_generations,
        provider: :self_hosted)
    end

    context 'when the self-hosted model exists' do
      it 'returns feature settings for the specified self-hosted model' do
        result = described_class.for_self_hosted_model(self_hosted_model.id)

        expect(result).to match_array([feature_setting])
      end
    end

    context 'when the self-hosted model does not exist' do
      it 'returns an empty collection' do
        result = described_class.for_self_hosted_model(non_existing_record_id)

        expect(result).to be_empty
      end
    end
  end

  describe '.feature_flagged_features' do
    let_it_be(:stable_features) { Ai::FeatureSetting::STABLE_FEATURES.dup.stringify_keys }
    let_it_be(:feature_flagged_features) { Ai::FeatureSetting::FLAGGED_FEATURES.dup.stringify_keys }

    context 'when ai_duo_chat_sub_features_settings FF is disabled' do
      before do
        stub_feature_flags(ai_duo_chat_sub_features_settings: false)
      end

      it 'returns only stable features' do
        expect(described_class.allowed_features).to eq(stable_features)
      end

      it 'does not include flagged features' do
        expect(described_class.allowed_features.keys).not_to include(*feature_flagged_features.keys)
      end
    end

    context 'when ai_duo_chat_sub_features_settings feature is enabled' do
      it 'returns both stable and flagged features' do
        expect(described_class.allowed_features).to eq(stable_features.merge(feature_flagged_features))
      end
    end
  end

  describe '#base_url' do
    let(:url) { "http://localhost:5000" }

    it 'returns Gitlab::AiGateway.url for self hosted features' do
      expect(Gitlab::AiGateway).to receive(:url).and_return(url)

      expect(build(:ai_feature_setting, provider: :self_hosted).base_url).to eq(url)
    end

    it 'returns Gitlab::AiGateway.cloud_connector_url for vendored features' do
      expect(Gitlab::AiGateway).to receive(:cloud_connector_url).and_return(url)

      expect(build(:ai_feature_setting, provider: :vendored).base_url).to eq(url)
    end
  end

  describe '#metadata' do
    let(:feature_setting) { create(:ai_feature_setting) }

    before do
      allow(Ai::FeatureSetting::FEATURE_METADATA)
        .to receive(:[]).with(feature_setting.feature.to_s)
        .and_return(feature_metadata)
    end

    context 'when feature metadata exists' do
      let(:feature_metadata) do
        { 'title' => 'Duo Chat', 'main_feature' => 'duo_chat', 'compatible_llms' => ['codellama'],
          'release_state' => 'BETA' }
      end

      it 'returns a FeatureMetadata object with correct attributes' do
        metadata = feature_setting.metadata

        expect(metadata).to be_an_instance_of(Ai::FeatureSetting::FeatureMetadata)
        expect(metadata.title).to eq('Duo Chat')
        expect(metadata.main_feature).to eq('duo_chat')
        expect(metadata.compatible_llms).to eq(['codellama'])
        expect(metadata.release_state).to eq('BETA')
      end
    end

    context 'when feature metadata does not exist' do
      let(:feature_metadata) { nil }

      it 'returns a FeatureMetadata object with nil attributes' do
        metadata = feature_setting.metadata

        expect(metadata).to be_an_instance_of(Ai::FeatureSetting::FeatureMetadata)
        expect(metadata.title).to be nil
        expect(metadata.main_feature).to be nil
        expect(metadata.compatible_llms).to be nil
        expect(metadata.release_state).to be nil
      end
    end
  end

  describe '#compatible_self_hosted_models' do
    let_it_be(:llm_names) { %w[codegemma deepseekcoder mistral codellama] }
    let_it_be(:models) do
      llm_names.map do |llm_name|
        create(:ai_self_hosted_model, name: "vllm_#{llm_name}", model: llm_name)
      end
    end

    let(:feature_setting) { create(:ai_feature_setting, feature: :code_generations) }

    before do
      allow(Ai::FeatureSetting::FEATURE_METADATA)
        .to receive(:[]).with(feature_setting.feature.to_s)
        .and_return(feature_metadata)
    end

    context 'with compatible LLMs assigned to the feature' do
      let(:feature_metadata) do
        { 'title' => 'Code Generation', 'main_feature' => 'Code Suggestion',
          'compatible_llms' => %w[deepseekcoder codellama], 'release_state' => 'GA' }
      end

      it 'returns the compatible self-hosted models' do
        expected_result = [models[1], models[3]]
        expect(feature_setting.compatible_self_hosted_models).to match_array(expected_result)
      end
    end

    context 'with no compatible LLMs assigned to the feature' do
      let(:feature_metadata) do
        { 'title' => 'Code Generation', 'main_feature' => 'Code Suggestion', 'compatible_llms' => [],
          'release_state' => 'BETA' }
      end

      it 'returns all the self-hosted models' do
        expect(feature_setting.compatible_self_hosted_models).to match_array(::Ai::SelfHostedModel.all)
      end
    end

    context 'with no feature metadata' do
      let(:feature_metadata) { nil }

      it 'returns all the self-hosted models' do
        expect(feature_setting.compatible_self_hosted_models).to match_array(::Ai::SelfHostedModel.all)
      end
    end
  end

  describe 'validation of self-hosted model' do
    let(:feature_setting) { build(:ai_feature_setting, feature: :duo_chat) }
    let(:self_hosted_model) { create(:ai_self_hosted_model) }

    context 'when provider is not self_hosted' do
      it 'does not add any errors' do
        feature_setting.provider = :vendored
        feature_setting.validate
        expect(feature_setting.errors[:self_hosted_model]).to be_empty
      end
    end

    context 'when provider is self_hosted' do
      before do
        feature_setting.provider = :self_hosted
        feature_setting.self_hosted_model = self_hosted_model
      end

      context 'when compatible_llms is not present' do
        it 'does not add any errors' do
          allow(feature_setting).to receive(:compatible_llms).and_return([])
          feature_setting.validate
          expect(feature_setting.errors[:self_hosted_model]).to be_empty
        end
      end

      context 'when compatible_llms is present' do
        let(:compatible_llms) { %w[mistral deepseekcoder codegemma] }

        before do
          allow(feature_setting).to receive(:compatible_llms).and_return(compatible_llms)
        end

        context 'when self_hosted_model is compatible' do
          it 'does not add any errors' do
            self_hosted_model.model = :mistral
            feature_setting.validate
            expect(feature_setting.errors[:self_hosted_model]).to be_empty
          end
        end

        context 'when self_hosted_model is not compatible' do
          it 'adds an error message' do
            incompatible_model = :codellama
            self_hosted_model.model = incompatible_model
            feature_setting.validate
            expect(feature_setting.errors[:base])
              .to include("#{incompatible_model.capitalize} is incompatible with the #{feature_setting.title} feature")
          end
        end
      end
    end
  end
end
