# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::RemoveDormantMembersWorker, :saas, feature_category: :seat_cost_management do
  let(:worker) { described_class.new }

  describe '#perform_work' do
    subject(:perform_work) { worker.perform_work }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      stub_feature_flags(limited_capacity_dormant_member_removal: true)
    end

    context 'with Groups requiring dormant member review', :freeze_time do
      let_it_be(:group, reload: true) { create(:group) }

      before do
        group.namespace_settings.update!(remove_dormant_members: true, last_dormant_member_review_at: 2.days.ago)
      end

      context 'with dormant members', :enable_admin_mode do
        let_it_be(:active_assignment) do
          create(:gitlab_subscription_seat_assignment, namespace: group, last_activity_on: Time.zone.today)
        end

        let_it_be(:dormant_assignment) do
          create(:gitlab_subscription_seat_assignment, namespace: group, last_activity_on: 91.days.ago)
        end

        it_behaves_like 'an idempotent worker' do
          it 'only removes dormant members' do
            expect { perform_work }.to change { Members::DeletionSchedule.count }.from(0).to(1)
          end

          it 'updates last_dormant_member_review_at' do
            expect { perform_work }.to change { group.namespace_settings.reload.last_dormant_member_review_at }
          end

          context 'when the dormant member is an owner of the group' do
            it 'does not remove the owner' do
              group.add_owner(dormant_assignment.user)

              expect { perform_work }.not_to change { Members::DeletionSchedule.count }
            end
          end
        end

        context 'when group has non-default dormant period' do
          it 'respects the group dormant period' do
            group.namespace_settings.update!(remove_dormant_members_period: 150)
            expect do
              perform_work
            end.not_to change { Members::DeletionSchedule.count }
          end
        end
      end
    end

    context 'with no Namespaces requiring refresh' do
      let_it_be(:setting) do
        create(:namespace_settings, last_dormant_member_review_at: 1.hour.ago, remove_dormant_members: true)
      end

      it 'does not update last_dormant_member_review_at' do
        expect { perform_work }.not_to change { setting.reload.last_dormant_member_review_at }
      end
    end
  end

  describe '#max_running_jobs' do
    subject { worker.max_running_jobs }

    it { is_expected.to eq(described_class::MAX_RUNNING_JOBS) }
  end

  describe '#remaining_work_count', :freeze_time do
    let_it_be(:namespaces_requiring_dormant_member_removal) do
      create_list(:namespace_settings, 8, last_dormant_member_review_at: 3.days.ago, remove_dormant_members: true)
    end

    subject(:remaining_work_count) { worker.remaining_work_count }

    context 'when there is remaining work' do
      it { is_expected.to eq(described_class::MAX_RUNNING_JOBS + 1) }
    end

    context 'when there is no remaining work' do
      before do
        namespaces_requiring_dormant_member_removal.map do |setting|
          setting.update!(last_dormant_member_review_at: Time.current)
        end
      end

      it { is_expected.to eq(0) }
    end
  end
end
