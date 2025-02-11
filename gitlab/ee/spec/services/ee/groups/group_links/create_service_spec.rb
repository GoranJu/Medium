# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::GroupLinks::CreateService, '#execute', feature_category: :groups_and_projects do
  let_it_be(:shared_with_group) { create(:group, :private) }
  let_it_be(:group) { create(:group, :private) }

  let_it_be(:user) { create(:user) }

  let(:role) { Gitlab::Access::DEVELOPER }
  let(:opts) { { shared_group_access: role, expires_at: nil } }

  let(:service) { described_class.new(group, shared_with_group, user, opts) }

  subject(:create_service) { service.execute }

  describe 'audit event creation' do
    let(:audit_context) do
      {
        name: 'group_share_with_group_link_created',
        stream_only: false,
        author: user,
        scope: group,
        target: shared_with_group,
        message: "Invited #{shared_with_group.name} to the group #{group.name}"
      }
    end

    before do
      shared_with_group.add_guest(user)
      group.add_owner(user)
    end

    it 'sends an audit event' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).once

      create_service
    end
  end

  context 'when current user has admin_group_member custom permission' do
    let_it_be_with_reload(:member) { create(:group_member, group: group, user: user) }
    let_it_be_with_reload(:member_role) { create(:member_role, namespace: group, admin_group_member: true) }

    shared_examples 'adding members using custom permission' do
      before do
        shared_with_group.add_guest(user)

        # it is more efficient to change the base_access_level than to create a new member_role
        member_role.base_access_level = current_role
        member_role.save!(validate: false)

        member.update!(access_level: current_role, member_role: member_role)
      end

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'when adding group link with the same access role as current user' do
          let(:role) { current_role }

          it 'adds a group link' do
            expect { create_service }.to change { group.shared_with_group_links.count }.by(1)
          end
        end

        context 'when adding group link with higher role than current user' do
          let(:role) { higher_role }

          it 'fails to add the group link' do
            expect { create_service }.not_to change { group.shared_with_group_links.count }
          end
        end
      end

      context 'when custom_roles feature is disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        context 'when adding members with the same access role as current user' do
          let(:role) { current_role }

          it 'fails to add the group link' do
            expect { create_service }.not_to change { group.shared_with_group_links.count }
          end
        end
      end
    end

    context 'for guest member role' do
      let(:current_role) { Gitlab::Access::GUEST }
      let(:higher_role) { Gitlab::Access::REPORTER }

      it_behaves_like 'adding members using custom permission'
    end

    context 'for reporter member role' do
      let(:current_role) { Gitlab::Access::REPORTER }
      let(:higher_role) { Gitlab::Access::DEVELOPER }

      it_behaves_like 'adding members using custom permission'
    end

    context 'for developer member role' do
      let(:current_role) { Gitlab::Access::DEVELOPER }
      let(:higher_role) { Gitlab::Access::MAINTAINER }

      it_behaves_like 'adding members using custom permission'
    end

    context 'for maintainer member role' do
      let(:current_role) { Gitlab::Access::MAINTAINER }
      let(:higher_role) { Gitlab::Access::OWNER }

      it_behaves_like 'adding members using custom permission'
    end

    context 'when assigning a member role to group link' do
      let_it_be(:member_role) { create(:member_role, namespace: group) }

      let(:opts) { { shared_group_access: Gitlab::Access::DEVELOPER, member_role_id: member_role.id } }

      before do
        group.add_owner(user)
        shared_with_group.add_guest(user)

        allow(service).to receive(:custom_role_for_group_link_enabled?)
          .with(group)
          .and_return(custom_role_for_group_link_enabled)
      end

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'when `custom_role_for_group_link_enabled` is true' do
          let(:custom_role_for_group_link_enabled) { true }

          it 'assigns member role to group link' do
            expect(create_service[:link][:member_role_id]).to eq(member_role.id)
          end

          context 'when the member role is in a different namespace' do
            let_it_be(:member_role) { create(:member_role, namespace: create(:group)) }

            it 'returns error' do
              expect(create_service[:status]).to eq(:error)
              expect(create_service[:message]).to eq("Group must be in same hierarchy as custom role's namespace")
            end
          end

          context 'when the member role is created on the instance-level' do
            let_it_be(:member_role) { create(:member_role, :instance) }

            before do
              stub_saas_features(gitlab_com_subscriptions: false)
            end

            it 'assigns member role to group link' do
              expect(create_service[:link][:member_role_id]).to eq(member_role.id)
            end
          end
        end

        context 'when `custom_role_for_group_link_enabled` is false' do
          let(:custom_role_for_group_link_enabled) { false }

          it 'does not assign member role to group link' do
            expect(create_service[:link][:member_role_id]).to be_nil
          end
        end
      end

      context 'when custom_roles feature is disabled' do
        let(:custom_role_for_group_link_enabled) { false }

        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'does not assign member role to group link' do
          expect(create_service[:link][:member_role_id]).to be_nil
        end
      end
    end
  end
end
