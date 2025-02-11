# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeGeneration::AiGatewaySelfHostedMessages, feature_category: :"self-hosted_models" do
  let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :self_hosted) }
  let_it_be(:current_user) { create(:user) }

  let(:prompt_version) { 2 }

  let(:content_above_cursor) do
    <<~CONTENT_ABOVE_CURSOR
      "binary search desc that ends in lots of random #{'a' * 1000}"
    CONTENT_ABOVE_CURSOR
  end

  let(:content_below_cursor) do
    <<~CONTENT_BELOW_CURSOR
      def use_binary_search
        // this is a random comment with lots of random letter #{'b' * 1000}
      end
    CONTENT_BELOW_CURSOR
  end

  let(:comment) { 'Generate a binary search method.' }
  let(:instruction) { instance_double(CodeSuggestions::Instruction, instruction: comment, trigger_type: 'comment') }

  let(:params) do
    {
      instruction: instruction
    }
  end

  subject(:prompt) { described_class.new(feature_setting: feature_setting, params: params, current_user: current_user) }

  describe '#request_params' do
    let(:request_params) do
      {
        model_provider: described_class::MODEL_PROVIDER,
        model_name: feature_setting.self_hosted_model.model,
        prompt_version: prompt_version,
        model_endpoint: feature_setting.self_hosted_model.endpoint,
        model_api_key: feature_setting.self_hosted_model.api_token,
        model_identifier: "provider/some-model",
        prompt_id: described_class::PROMPT_ID
      }
    end

    it 'returns expected request params with instruction' do
      expect(prompt.request_params).to eq(request_params.merge(prompt: comment))
    end

    context 'when instruction is missing' do
      let(:instruction) { nil }

      it 'sends an empty instruction' do
        expect(prompt.request_params).to eq(
          request_params.merge(prompt: "")
        )
      end
    end
  end

  describe '#pick_content_above_cursor' do
    let(:params) do
      {
        current_file: {
          content_above_cursor: content_above_cursor
        }
      }
    end

    it 'returns the last 500 characters of the content' do
      expected_output = "#{'a' * 498}\"\n"

      expect(prompt.send(:pick_content_above_cursor)).to eq(expected_output)
    end
  end

  describe '#pick_content_below_cursor' do
    let(:params) do
      {
        current_file: {
          content_below_cursor: content_below_cursor
        }
      }
    end

    it 'returns the first 500 characters of the content' do
      expected_output = <<~EXPECTED.chomp
        def use_binary_search
          // this is a random comment with lots of random letter #{'b' * 421}
      EXPECTED

      expect(prompt.send(:pick_content_below_cursor)).to eq(expected_output)
    end
  end
end
