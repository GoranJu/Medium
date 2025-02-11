# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::Admin, feature_category: :permissions do
  subject(:instance_authorization) { described_class.new(user) }

  let_it_be(:user) { create(:user) }
  let_it_be(:admin_role) { create(:admin_role, :read_admin_dashboard, user: user) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe "#permitted" do
    subject(:permitted) { instance_authorization.permitted }

    it 'includes the ability' do
      is_expected.to eq([:read_admin_dashboard])
    end
  end
end
