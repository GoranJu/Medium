# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::ReviewMergeRequest, feature_category: :code_review_workflow do
  describe '#to_prompt' do
    let(:diff) { "@@ -1,4 +1,4 @@\n # NEW\n \n-Welcome\n-This is a new file\n+Welcome!\n+This is a new file." }
    let(:new_path) { 'NEW.md' }
    let(:hunk) { '-Welcome\n-This is a new file+Welcome!\n+This is a new file.' }

    let(:prompt) { described_class.new(new_path, diff, hunk).to_prompt }

    subject(:user_prompt) { prompt&.dig(:messages, 0, :content) }

    it 'includes new_path' do
      expect(user_prompt).to include(new_path)
    end

    it 'includes diff lines' do
      expect(user_prompt).to include(
        <<~CONTENT
          <line old_line="1" new_line="1"># NEW</line>
          <line old_line="2" new_line="2"></line>
          <line old_line="3" new_line="">Welcome</line>
          <line old_line="4" new_line="">This is a new file</line>
          <line old_line="" new_line="3">Welcome!</line>
          <line old_line="" new_line="4">This is a new file.</line>
        CONTENT
      )
    end

    it 'uses Claude 3.5 Sonnet' do
      expect(prompt[:model]).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_3_5_SONNET)
    end

    it 'specifies the system prompt' do
      expect(prompt[:system]).to eq(described_class::SYSTEM_MESSAGE[1])
    end
  end
end
