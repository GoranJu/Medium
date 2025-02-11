# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoAddOn, feature_category: :subscription_management do
  describe '.any_add_on_purchased_or_trial?' do
    subject { described_class.any_add_on_purchased_or_trial?(namespace) }

    let_it_be(:namespace) { create(:group) }

    context 'when add on is duo pro' do
      before do
        allow(described_class).to receive(:gitlab_com_subscription?).and_return(true)
      end

      context 'when active add_on' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, namespace: namespace)
        end

        it { is_expected.to be(true) }
      end

      context 'when on trial' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :trial, namespace: namespace)
        end

        it { is_expected.to be(true) }
      end

      context 'when on expired trial' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :expired_trial, namespace: namespace)
        end

        it { is_expected.to be(true) }
      end

      context 'when on trial expired 11 days ago' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :trial,
            namespace: namespace,
            expires_on: 11.days.ago
          )
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when add on is duo enterprise' do
      before do
        allow(described_class).to receive(:gitlab_com_subscription?).and_return(true)
      end

      context 'when active add_on' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
        end

        it { is_expected.to be(true) }
      end

      context 'when on trial' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :trial, namespace: namespace)
        end

        it { is_expected.to be(true) }
      end

      context 'when on expired trial' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :expired_trial, namespace: namespace)
        end

        it { is_expected.to be(true) }
      end

      context 'when on trial expired 11 days ago' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :trial,
            namespace: namespace,
            expires_on: 11.days.ago
          )
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when add on is on instance level' do
      before do
        allow(described_class).to receive(:gitlab_com_subscription?).and_return(false)
      end

      context 'when active add_on' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed)
        end

        it { is_expected.to be(true) }
      end

      context 'when on trial' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed, :trial)
        end

        it { is_expected.to be(true) }
      end

      context 'when on expired trial' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed, :expired_trial)
        end

        it { is_expected.to be(true) }
      end

      context 'when on trial expired 11 days ago' do
        let_it_be(:add_on_purchase_on) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed, :trial,
            expires_on: 11.days.ago
          )
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when namespace does not have an add_on' do
      it { is_expected.to be(false) }
    end
  end
end
