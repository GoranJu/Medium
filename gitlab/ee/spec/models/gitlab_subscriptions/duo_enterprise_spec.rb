# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoEnterprise, feature_category: :subscription_management do
  describe '.no_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.no_add_on_purchase_for_namespace?(namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when the add-on purchase is expired for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :expired, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when there is no add-on purchase for the namespace' do
      it { is_expected.to be(true) }
    end
  end

  describe '.namespace_eligible?', :saas do
    subject { described_class.namespace_eligible?(namespace) }

    context 'when namespace has an eligible plan' do
      let_it_be(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }

      context 'when namespace is an ultimate plan' do
        it { is_expected.to be(true) }
      end

      context 'when an add-on purchase exists for the namespace' do
        before_all do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when namespace does not have an eligible plan' do
      let_it_be(:namespace) { create(:group_with_plan, plan: :premium_plan) }

      it { is_expected.to be(false) }
    end
  end

  describe '.namespace_plan_eligible?', :saas do
    subject { described_class.namespace_plan_eligible?(namespace) }

    context 'when namespace has an ultimate plan' do
      let(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }

      it { is_expected.to be true }
    end

    context 'when namespace has a non-ultimate plan' do
      let(:namespace) { create(:group) }

      it { is_expected.to be false }
    end
  end
end
