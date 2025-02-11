# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::ResponseModifiers::EmptyResponseModifier, feature_category: :duo_chat do
  context 'when no message is passed' do
    subject(:response_modifier) { described_class.new }

    it 'parses content from the ai response' do
      expect(response_modifier.response_body).to eq('')
    end

    it 'returns empty errors' do
      expect(response_modifier.errors).to be_empty
    end
  end

  context 'when message is passed' do
    let(:message) { 'Some message' }

    subject(:response_modifier) { described_class.new(message) }

    it 'parses content from the ai response' do
      expect(response_modifier.response_body).to eq(message)
    end

    it 'returns empty errors' do
      expect(response_modifier.errors).to be_empty
    end
  end

  context 'when error code is present' do
    let(:message) { 'Some message.' }
    let(:error_code) { 'M3001' }

    subject(:response_modifier) { described_class.new(message, error_code: error_code) }

    it 'appends the error code and troubleshooting link to the message' do
      expected_url = "#{Gitlab::Saas.doc_url}/ee/user/gitlab_duo_chat/troubleshooting.html#error-#{error_code.downcase}"
      error_code_message = "[#{error_code}](#{expected_url})"
      expected_message = "#{message} #{_('Error code')}: #{error_code_message}"
      expect(response_modifier.response_body).to eq(expected_message)
    end

    it 'returns empty errors' do
      expect(response_modifier.errors).to be_empty
    end
  end
end
