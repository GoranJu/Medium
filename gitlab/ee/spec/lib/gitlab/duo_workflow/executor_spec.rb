# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::DuoWorkflow::Executor, feature_category: :duo_workflow do
  before do
    stub_config(
      duo_workflow: {
        executor_binary_url: 'https://example.com/executor',
        executor_version: 'v1.2.3'
      }
    )
  end

  describe '.executor_binary_url' do
    it 'returns the executor binary URL from config' do
      expect(described_class.executor_binary_url).to eq('https://example.com/executor')
    end
  end

  describe '.version' do
    it 'returns the executor version from config' do
      expect(described_class.version).to eq('v1.2.3')
    end
  end
end
