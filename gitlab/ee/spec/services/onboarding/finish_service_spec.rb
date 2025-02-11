# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FinishService, feature_category: :onboarding do
  describe '#execute' do
    let_it_be(:user, reload: true) { create(:user, onboarding_in_progress: true) }

    subject(:execute) { described_class.new(user).execute }

    context 'when user qualifies as onboarding' do
      before do
        stub_saas_features(onboarding: true)
      end

      it 'updates onboarding_in_progress to false' do
        expect { execute }.to change { user.onboarding_in_progress }.from(true).to(false)
      end
    end

    context 'when user does not qualify as onboarding' do
      before do
        stub_saas_features(onboarding: false)
      end

      it 'does not update onboarding_in_progress' do
        expect { execute }.not_to change { user.onboarding_in_progress }
        expect(user).to be_onboarding_in_progress
      end
    end
  end
end
