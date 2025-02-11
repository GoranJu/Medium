# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::BillableUsersUtils, feature_category: :consumables_cost_management do
  let_it_be(:dummy_class) { Class.new { include GitlabSubscriptions::BillableUsersUtils }.new }

  billable_roles = [Gitlab::Access::PLANNER, Gitlab::Access::REPORTER, Gitlab::Access::DEVELOPER,
    Gitlab::Access::MAINTAINER, Gitlab::Access::OWNER, Gitlab::Access::ADMIN].freeze

  sm_non_billable_roles = [Gitlab::Access::NO_ACCESS].freeze
  sm_excluding_guests_billable_roles = [Gitlab::Access::GUEST, Gitlab::Access::MINIMAL_ACCESS].freeze

  saas_non_billable_roles = [Gitlab::Access::NO_ACCESS, Gitlab::Access::MINIMAL_ACCESS].freeze
  saas_excluding_guests_billable_roles = [Gitlab::Access::GUEST].freeze

  shared_examples 'billable_role_change? returns' do |expected|
    let(:member_role_id) { nil }

    it { is_expected.to eq(expected) }
  end

  shared_examples 'billable_role_change? for GUEST' do
    let(:member_role_id) { nil }

    context 'when subscription does not exclude guests' do
      it { is_expected.to eq(true) }
    end

    context 'when subscription excludes guests' do
      let(:plan) { License::ULTIMATE_PLAN }

      it { is_expected.to eq(false) }
    end
  end

  shared_examples 'billable_role_change? with member_role_id' do |role_sym, without_billable_role, with_billable_role|
    let(:plan) { License::ULTIMATE_PLAN }

    context 'when member_role is non billable' do
      let(:member_role) { create(:member_role, role_sym, :non_billable, namespace: namespace) }
      let(:member_role_id) { member_role.id }

      it { is_expected.to eq(without_billable_role) }
    end

    context 'when member_role is billable' do
      let(:member_role) { create(:member_role, role_sym, :billable, namespace: namespace) }
      let(:member_role_id) { member_role.id }

      it { is_expected.to eq(with_billable_role) }
    end
  end

  shared_examples 'raises InvalidSubscriptionTypeError' do
    let(:role) { Gitlab::Access::DEVELOPER }
    let(:member_role_id) { nil }

    it 'raises an InvalidSubscriptionTypeError' do
      expect { subject }.to raise_error(
        GitlabSubscriptions::BillableUsersUtils::InvalidSubscriptionTypeError
      )
    end
  end

  shared_examples 'feature disabled' do
    before do
      stub_feature_flags(member_promotion_management: false)
    end

    let(:role) { Gitlab::Access::DEVELOPER }
    let(:member_role_id) { nil }

    it 'raises a Runtime Error' do
      expect { subject }.to raise_error(
        RuntimeError, 'Attempted to use a WIP feature that is not enabled!'
      )
    end
  end

  shared_context 'when self_managed' do
    subject(:sm_billable_role_change?) do
      dummy_class.sm_billable_role_change?(role: role, member_role_id: member_role_id)
    end

    let(:namespace) { nil }
    let(:plan) { License::STARTER_PLAN }
    let(:license) { create(:license, plan: plan) }

    before do
      allow(License).to receive(:current).and_return(license)
    end
  end

  shared_context 'when saas' do
    subject(:saas_billable_role_change?) do
      dummy_class.saas_billable_role_change?(role: role, target_namespace: namespace, member_role_id: member_role_id)
    end

    let(:namespace) { create(:group) }
    let(:plan) { License::STARTER_PLAN }

    before do
      allow(namespace).to receive(:actual_plan_name).and_return(plan)
    end
  end

  shared_examples 'billable_role_change?' do |billable_roles, non_billable_roles, guest_like_billable_roles|
    billable_roles.each do |role|
      context "when role is #{role}" do
        let(:role) { role }

        it_behaves_like 'billable_role_change? returns', true
      end
    end

    non_billable_roles.each do |role|
      context "when role is #{role}" do
        let(:role) { role }

        it_behaves_like 'billable_role_change? returns', false
      end
    end

    guest_like_billable_roles.each do |role|
      context "when role is #{role}" do
        let(:role) { role }

        it_behaves_like 'billable_role_change? for GUEST'
      end
    end

    context 'with member_role_id' do
      context 'when role is GUEST' do
        let(:role) { Gitlab::Access::GUEST }

        it_behaves_like "billable_role_change? with member_role_id", :guest, false, true
      end

      context 'when role is MINIMAL ACCESS' do
        let(:role) { Gitlab::Access::MINIMAL_ACCESS }

        it_behaves_like "billable_role_change? with member_role_id", :minimal_access, true, true
      end
    end
  end

  describe '#sm_billable_role_change?' do
    include_context 'when self_managed'

    context 'when called from sm' do
      it_behaves_like 'billable_role_change?',
        billable_roles, sm_non_billable_roles, sm_excluding_guests_billable_roles

      it_behaves_like 'feature disabled'
    end

    context 'when called from saas', :saas do
      it_behaves_like 'raises InvalidSubscriptionTypeError'
    end
  end

  describe '#saas_billable_role_change?' do
    include_context 'when saas'

    context 'when called from saas', :saas do
      it_behaves_like 'billable_role_change?',
        billable_roles, saas_non_billable_roles, saas_excluding_guests_billable_roles

      it_behaves_like 'feature disabled'
    end

    context 'when called from sm' do
      it_behaves_like 'raises InvalidSubscriptionTypeError'
    end
  end

  describe 'access levels' do
    # if this test fails please consider adding appropriate billable member handling in
    # billable_users_utils.rb for the new AccessLevel that has been added
    it 'tests billable logic for all valid Gitlab Access Levels' do
      access_roles = billable_roles + sm_non_billable_roles + sm_excluding_guests_billable_roles +
        saas_non_billable_roles + saas_excluding_guests_billable_roles

      uniq_access_roles = access_roles.uniq
      uniq_access_roles.delete(Gitlab::Access::NO_ACCESS) # no access usually is when user isn't logged in
      uniq_access_roles.delete(Gitlab::Access::ADMIN)

      expect(uniq_access_roles).to match_array(Gitlab::Access.values_with_minimal_access)
    end
  end
end
