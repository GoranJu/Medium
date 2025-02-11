# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::UserMemberRole, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:member_role) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validation' do
    subject(:user_member_role) { build(:user_member_role) }

    it { is_expected.to validate_presence_of(:member_role) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_uniqueness_of(:user) }
  end
end
