# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::VertexAi, feature_category: :code_suggestions do
  let_it_be(:current_user) { create(:user) }

  subject { described_class.new({}, current_user) }

  describe '#request_params' do
    it 'returns expected request params' do
      request_params = { prompt_version: 1 }

      expect(subject.request_params).to eq(request_params)
    end
  end
end
