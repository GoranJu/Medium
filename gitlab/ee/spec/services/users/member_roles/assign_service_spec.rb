# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::MemberRoles::AssignService, feature_category: :permissions do
  let_it_be(:member_role) { create(:member_role, :admin) }
  let_it_be(:user) { create(:user) }

  let_it_be_with_reload(:current_user) { create(:admin) }

  let(:member_role_param) { member_role }
  let(:params) { { user: user, member_role: member_role_param } }

  subject(:assign_member_role) { described_class.new(current_user, params).execute }

  before do
    stub_licensed_features(custom_roles: true)
  end

  context 'when current user is not an admin', :enable_admin_mode do
    before do
      current_user.update!(admin: false)
    end

    it 'returns an error' do
      expect(assign_member_role).to be_error
    end
  end

  context 'when current user is an admin', :enable_admin_mode do
    context 'when custom_ability_read_admin_dashboard FF is disabled' do
      before do
        stub_feature_flags(custom_ability_read_admin_dashboard: false)
      end

      it 'returns an error' do
        expect(assign_member_role).to be_error
      end
    end

    context 'when custom_ability_read_admin_dashboard FF is enabled' do
      context 'when member_role param is present' do
        it 'creates a new user member role relation' do
          expect { assign_member_role }.to change { Users::UserMemberRole.count }.by(1)
        end

        it 'returns success' do
          expect(assign_member_role).to be_success
        end
      end

      context 'when member_role param is null' do
        let_it_be(:other_user_member_role) { create(:user_member_role, member_role: member_role) }

        let(:member_role_param) { nil }

        context 'when user member role relation exists for the user' do
          let_it_be(:user_member_role) { create(:user_member_role, member_role: member_role, user: user) }

          it 'deletes the existing user member role relation' do
            expect { assign_member_role }.to change { Users::UserMemberRole.count }.by(-1)

            expect { user_member_role.reload }.to raise_error(ActiveRecord::RecordNotFound)
          end

          it 'returns success' do
            expect(assign_member_role).to be_success
          end
        end

        context 'when user member role relation does not exist for the user' do
          it 'does not delete any user member role relation' do
            expect { assign_member_role }.not_to change { Users::UserMemberRole.count }

            expect(other_user_member_role.reload).not_to be_nil
          end

          it 'returns error' do
            expect(assign_member_role).to be_error
          end
        end
      end

      context 'when the provided custom role is not an admin role' do
        let_it_be(:member_role) { create(:member_role) }

        it 'does not create a new user member role relation' do
          expect { assign_member_role }.not_to change { Users::UserMemberRole.count }
        end

        it 'returns error' do
          expect(assign_member_role).to be_error
        end
      end
    end
  end
end
