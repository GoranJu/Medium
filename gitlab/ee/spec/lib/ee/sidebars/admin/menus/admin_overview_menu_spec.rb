# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::AdminOverviewMenu, feature_category: :navigation do
  let_it_be(:user, refind: true) { create(:user) }

  subject(:menu) { described_class.new(Sidebars::Context.new(current_user: user, container: nil)) }

  describe '#render' do
    it { is_expected.not_to be_render }

    [
      :read_admin_dashboard,
      :read_admin_users
    ].each do |permission|
      context "when user has `#{permission}`" do
        let_it_be(:role) { create(:member_role, permission) }
        let_it_be(:membership) { create(:user_member_role, user: user, member_role: role) }

        before do
          allow(user).to receive(:can?).and_call_original
          allow(user).to receive(:can?).with(:access_admin_area).and_return(true)

          stub_licensed_features(custom_roles: true)
        end

        it { is_expected.to be_render }
      end
    end
  end

  describe "#renderable_items" do
    using RSpec::Parameterized::TableSyntax

    where(:permissions, :expected_menu_items) do
      [:read_admin_dashboard] | [_('Dashboard')]
      [:read_admin_users] | [_('Users')]
      [:read_admin_dashboard, :read_admin_users] | [_('Dashboard'), _('Users')]
    end

    with_them do
      context "when user has `#{params[:permissions]}`" do
        subject(:menu_items) { menu.renderable_items.map(&:title) }

        let!(:role) { create(:member_role, *permissions) }
        let!(:membership) { create(:user_member_role, user: user, member_role: role) }

        before do
          stub_licensed_features(custom_roles: true)
        end

        it { is_expected.to match_array(expected_menu_items) }
      end
    end
  end
end
