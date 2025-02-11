# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::UserMemberRolesForAdminPreloader, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }

  subject(:result) { described_class.new(user: user).execute }

  shared_examples 'custom roles' do |ability|
    let(:expected_abilities) { [ability].compact }

    context 'when custom_roles license is enabled' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'when group has custom role' do
        let_it_be(:member_role) do
          create(:admin_role, ability, user: user)
        end

        context 'when custom role has ability: true' do
          it 'returns all allowed abilities' do
            expect(result).to eq({ admin: expected_abilities })
          end

          context "when `#{ability}` is disabled" do
            before do
              allow(::MemberRole).to receive(:permission_enabled?)
                .and_call_original
              allow(::MemberRole).to receive(:permission_enabled?)
                .with(ability, user).and_return(false)
            end

            it { expect(result).to eq({ admin: [] }) }
          end
        end
      end
    end
  end

  MemberRole.all_customizable_admin_permission_keys.each do |ability|
    it_behaves_like 'custom roles', ability
  end
end
