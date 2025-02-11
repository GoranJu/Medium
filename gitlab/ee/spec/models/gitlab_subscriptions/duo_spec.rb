# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo, feature_category: :"add-on_provisioning" do
  describe '.enterprise_or_pro_for_namespace' do
    subject { described_class.enterprise_or_pro_for_namespace(namespace) }

    let(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }
    let(:expires_on) { 1.year.from_now.to_date }
    let(:namespace) { create(:namespace) }

    let!(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: namespace, expires_on: expires_on)
    end

    it { is_expected.to eq(add_on_purchase) }

    context 'with expired add-on purchase' do
      let(:expires_on) { 1.day.ago.to_date }

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'with different namespace' do
      subject { described_class.enterprise_or_pro_for_namespace("foo") }

      it { is_expected.to be_nil }
    end

    context 'with other duo add-on' do
      let(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'with multiple duo add-ons' do
      let(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

      let!(:duo_enterprise_add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: duo_enterprise_add_on,
          namespace: namespace,
          expires_on: expires_on
        )
      end

      it { is_expected.to eq(duo_enterprise_add_on_purchase) }
    end

    context 'with non Duo add-on' do
      let(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

      it { is_expected.to be_nil }
    end
  end

  describe '.no_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }

    subject { described_class.no_add_on_purchase_for_namespace?(namespace) }

    it { is_expected.to be(true) }

    context 'with active add-on purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: namespace)
      end

      it { is_expected.to be(false) }

      context 'with different namespace' do
        subject { described_class.no_add_on_purchase_for_namespace?('foo') }

        it { is_expected.to be(true) }
      end
    end

    context 'with expired add-on purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :expired, add_on: add_on, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'with active trial add-on purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :active_trial, add_on: add_on, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'with expired trial add-on purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :expired_trial, add_on: add_on, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'with other duo add-on' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'with non Duo add-on' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.any_add_on_purchase_for_namespace' do
    let_it_be(:namespace) { create(:namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
      end

      it 'returns the add-on purchase' do
        expect(described_class.any_add_on_purchase_for_namespace(namespace).id).to eq(add_on_purchase.id)
      end
    end

    context 'when the enterprise add-on purchase is expired for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :expired, namespace: namespace)
      end

      it 'returns the add-on purchase' do
        expect(described_class.any_add_on_purchase_for_namespace(namespace).id).to eq(add_on_purchase.id)
      end
    end

    context 'when there is a pro add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, namespace: namespace)
      end

      it 'returns the add-on purchase' do
        expect(described_class.any_add_on_purchase_for_namespace(namespace).id).to eq(add_on_purchase.id)
      end
    end

    context 'when the pro add-on purchase is expired for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :expired, namespace: namespace)
      end

      it 'returns the add-on purchase' do
        expect(described_class.any_add_on_purchase_for_namespace(namespace).id).to eq(add_on_purchase.id)
      end
    end

    context 'when there is no add-on purchase for the namespace' do
      it 'returns nil' do
        expect(described_class.any_add_on_purchase_for_namespace(namespace)).to be_nil
      end
    end
  end
end
