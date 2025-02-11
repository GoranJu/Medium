# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::BlockSeatOverages, feature_category: :seat_cost_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }

  let(:source) { subgroup }

  describe '.block_seat_overages?' do
    subject(:block_seat_overages?) { described_class.block_seat_overages?(source) }

    context 'when on GitLab.com', :saas do
      it 'delegates to root namespace' do
        expect(group).to receive(:block_seat_overages?)

        block_seat_overages?
      end
    end

    context 'when on self-managed' do
      let(:seat_control_block_overages) { 2 }
      let(:seat_control_off) { 0 }

      it 'returns true when seat control is set to block overages' do
        stub_application_setting(seat_control: seat_control_block_overages)

        expect(block_seat_overages?).to be true
      end

      it 'returns false when seat control is disabled' do
        stub_application_setting(seat_control: seat_control_off)

        expect(block_seat_overages?).to be false
      end
    end
  end

  describe '.seats_available_for?' do
    let(:invites) { [user1.id, user2.id] }
    let(:access_level) { Gitlab::Access::DEVELOPER }
    let(:member_role_id) { nil }
    let(:non_billable_member_role) { create(:member_role, :instance, :non_billable) }
    let(:billable_member_role) { create(:member_role, :instance, :billable) }
    let(:user3) { create(:user) }
    let(:user4) { create(:user) }
    let(:non_existing_email) { 'nonexistingemail@email.com' }

    let(:seats_available?) do
      described_class.seats_available_for?(source, invites, access_level, member_role_id)
    end

    context 'when on GitLab.com', :saas do
      it 'delegates to root namespace' do
        expect(group).to receive(:seats_available_for?).with(invites.map(&:to_s), access_level, member_role_id)

        seats_available?
      end
    end

    context 'when on self-managed' do
      let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
      let(:total_license_seats) { 0 }

      before do
        allow(License).to receive(:current).and_return(license)
        allow(license).to receive(:seats).and_return(total_license_seats)
      end

      context 'with non-billable members' do
        context 'with service bot users' do
          let(:service_bot) { create(:user, :bot) }
          let(:invites) { [service_bot.id] }

          it 'returns true' do
            expect(seats_available?).to be true
          end
        end

        context 'with minimal access level' do
          let(:access_level) { Gitlab::Access::MINIMAL_ACCESS }

          it 'returns true' do
            expect(seats_available?).to be true
          end
        end

        context 'with guest access level' do
          let(:access_level) { Gitlab::Access::GUEST }

          it 'returns true' do
            expect(seats_available?).to be true
          end
        end

        context 'with non-billable custom role' do
          let(:member_role_id) { non_billable_member_role.id }

          it 'returns true' do
            expect(seats_available?).to be true
          end
        end
      end

      context 'with billable members' do
        before do
          allow(described_class).to receive(:get_billable_user_ids).and_return([user1.id.to_s])
        end

        context 'when invites are existing billable members' do
          context 'with user ids' do
            let(:invites) { [user1.id] }

            it 'returns true' do
              expect(seats_available?).to be true
            end
          end

          context 'with string user ids' do
            let(:invites) { [user1.id.to_s] }

            it 'returns true' do
              expect(seats_available?).to be true
            end
          end

          context 'with existing user emails' do
            let(:invites) { [user1.email] }

            it 'returns true' do
              expect(seats_available?).to be true
            end
          end
        end

        context 'for new billable invites' do
          context 'with enough seats' do
            let(:total_license_seats) { 5 }

            context 'with mix of user id, id as string and emails' do
              let(:invites) { [user2.id, user4.id.to_s, user3.email, non_existing_email] }

              it 'returns true' do
                expect(seats_available?).to be true
              end
            end
          end

          context 'with not enough seats' do
            let(:total_license_seats) { 4 }

            context 'with mix of User id, id as string and emails' do
              let(:invites) { [user2.id, user4.id.to_s, user3.email, non_existing_email] }

              it 'returns false' do
                expect(seats_available?).to be false
              end
            end

            context 'with billable custom roles' do
              let(:total_license_seats) { 1 }
              let(:member_role_id) { billable_member_role.id }
              let(:invites) { [user2.id] }

              it 'returns false' do
                expect(seats_available?).to be false
              end
            end
          end
        end
      end
    end
  end
end
