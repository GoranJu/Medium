# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ai::SelfHosted::AiGateway, feature_category: :"self-hosted_models" do
  describe '.required?' do
    context 'when the license is not an offline cloud license' do
      it 'returns false' do
        expect(described_class.required?).to be(false)
      end
    end

    context 'when the license is an offline cloud license' do
      before do
        allow(::License).to receive_message_chain(:current, :offline_cloud_license?).and_return(true)
      end

      it 'returns true' do
        expect(described_class.required?).to be(true)
      end
    end
  end

  describe '.probes' do
    let(:user) { build(:user) }

    it 'returns an array with all expected probe instances' do
      probes = described_class.probes(user)

      expect(probes).to contain_exactly(
        an_instance_of(::CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe),
        an_instance_of(::CloudConnector::StatusChecks::Probes::HostProbe),
        an_instance_of(::CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe)
      )
    end
  end
end
