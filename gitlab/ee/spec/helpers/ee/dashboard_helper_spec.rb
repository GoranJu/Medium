# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DashboardHelper, type: :helper do
  let(:user) { build(:user) }

  describe '.has_start_trial?', :do_not_mock_admin_mode_setting do
    using RSpec::Parameterized::TableSyntax

    where(:has_license, :current_user, :output) do
      false | :admin | true
      false | :user  | false
      true  | :admin | false
      true  | :user  | false
    end

    with_them do
      let(:user) { create(current_user) } # rubocop:disable Rails/SaveBang
      let(:license) { has_license ? create(:license) : nil }
      subject { helper.has_start_trial? }

      before do
        allow(helper).to receive(:current_user).and_return(user)
        allow(License).to receive(:current).and_return(license)
      end

      it { is_expected.to eq(output) }
    end
  end

  describe '.user_groups_requiring_reauth', feature_category: :system_access do
    subject(:user_groups_requiring_reauth) { helper.user_groups_requiring_reauth }

    let!(:current_user) { create(:user) }

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
    end

    context 'when the user has no Group SAML identities' do
      it 'returns an empty array' do
        expect(user_groups_requiring_reauth).to be_empty
      end
    end

    context 'when the user has Group SAML identities' do
      let_it_be(:saml_provider) { create(:saml_provider, group: create(:group), enforced_sso: true) }

      before do
        stub_licensed_features(group_saml: true)
        create(:group_saml_identity, user: current_user, saml_provider: saml_provider)
      end

      context 'when access is not restricted' do
        it 'returns an empty array' do
          expect(user_groups_requiring_reauth).to be_empty
        end
      end

      context 'when access is restricted' do
        before do
          allow_next_instance_of(::Gitlab::Auth::GroupSaml::SsoEnforcer) do |instance|
            allow(instance).to receive(:access_restricted?).and_return(true)
          end
        end

        it 'returns the group that the SAML provider belongs to' do
          expect(user_groups_requiring_reauth).to match_array(saml_provider.group)
        end
      end
    end
  end
end
