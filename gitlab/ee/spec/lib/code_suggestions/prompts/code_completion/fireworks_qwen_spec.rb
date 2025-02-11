# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::FireworksQwen, feature_category: :code_suggestions do
  let_it_be(:current_user) { create(:user) }

  subject(:fireworks_qwen_prompt) { described_class.new({}, current_user) }

  describe '#request_params' do
    it 'returns expected request params' do
      request_params = {
        prompt_version: 1,
        model_name: "qwen2p5-coder-7b",
        model_provider: "fireworks_ai"
      }
      expect(fireworks_qwen_prompt.request_params).to eq(request_params)
    end
  end
end
