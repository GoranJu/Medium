# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::FeatureAuthorizer, feature_category: :ai_abstraction_layer do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:feature_name) { :summarize_review }
  let(:instance) do
    described_class.new(
      container: group,
      feature_name: feature_name,
      user: user
    )
  end

  subject(:allowed?) { instance.allowed? }

  describe '#allowed?' do
    before do
      allow(user).to receive(:allowed_to_use?).and_return(true)
    end

    context 'when container has correct setting and license' do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
      end

      context 'when ai_global_switch is turned off' do
        it 'returns false' do
          stub_feature_flags(ai_global_switch: false)

          expect(allowed?).to be false
        end
      end

      context 'when duo features are disabled on container' do
        it 'returns false' do
          group.namespace_settings.update!(duo_features_enabled: false)

          expect(allowed?).to be false
        end
      end
    end

    context 'when user is not allowed to use feature' do
      before do
        allow(user).to receive(:allowed_to_use?).and_return(false)
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when container does not have correct license' do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(false)
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when container is not present' do
      let(:instance) do
        described_class.new(
          container: nil,
          feature_name: feature_name,
          user: user
        )
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when user is not present' do
      let(:instance) do
        described_class.new(
          container: group,
          feature_name: feature_name,
          user: nil
        )
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end
  end
end
