# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoWorkflow::Client, feature_category: :duo_workflow do
  let(:user) { create(:user) }
  let(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }

  before do
    allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
  end

  describe '.url' do
    it 'returns configured url' do
      expect(described_class.url).to eq("duo-workflow-service.example.com:50052")
    end
  end

  describe '.headers' do
    it 'returns cloud connector headers' do
      expect(::CloudConnector).to receive(:ai_headers).with(user).and_return({ header_key: 'header_value' })

      expect(described_class.headers(user: user)).to eq({ header_key: 'header_value' })
    end
  end

  describe '.secure?' do
    it 'returns secure config' do
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return true
      expect(described_class.secure?).to eq(true)
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return false
      expect(described_class.secure?).to eq(false)
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return nil
      expect(described_class.secure?).to eq(false)
    end
  end
end
