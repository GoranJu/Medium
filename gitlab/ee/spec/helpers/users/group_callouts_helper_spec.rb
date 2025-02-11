# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::GroupCalloutsHelper, feature_category: :groups_and_projects do
  describe '#show_compliance_framework_settings_moved_callout?' do
    let_it_be(:group) { build(:group, :private, name: 'private namespace') }
    let_it_be(:user) { build(:user) }

    subject(:show_callout) { helper.show_compliance_framework_settings_moved_callout?(group) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'when alert can be shown' do
      before do
        allow(helper).to receive(:user_dismissed_for_group)
          .with('compliance_framework_settings_moved_callout', group)
          .and_return(false)
      end

      it 'returns true' do
        expect(show_callout).to be true
      end
    end

    context 'when alert is dismissed' do
      before do
        allow(helper).to receive(:user_dismissed_for_group)
          .with('compliance_framework_settings_moved_callout', group)
          .and_return(true)
      end

      it 'returns false' do
        expect(show_callout).to be false
      end
    end
  end
end
