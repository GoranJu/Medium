# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::FeatureFlagEnabler, feature_category: :duo_chat do
  it 'enables feature flags by group ai framework' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::ai framework', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'does not enable feature flags by other groups' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::code suggestions', name: 'test_f') })
    expect(Feature).not_to receive(:enable).with(:test_f)

    described_class.execute
  end
end
