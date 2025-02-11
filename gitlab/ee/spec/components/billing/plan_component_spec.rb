# frozen_string_literal: true
require "spec_helper"

RSpec.describe Billing::PlanComponent, :aggregate_failures, type: :component, feature_category: :subscription_management do
  include SubscriptionPortalHelpers

  let(:namespace) { build(:group) }
  let(:plans_data) { billing_plans_data.map { |plan| Hashie::Mash.new(plan) } }
  let(:plan) { plans_data.detect { |x| x.code == plan_name } }
  let(:current_plan_code) { nil }
  let(:current_plan) { Hashie::Mash.new({ code: current_plan_code }) }

  subject(:component) { described_class.new(plan: plan, namespace: namespace, current_plan: current_plan) }

  before do
    allow(component).to receive(:plan_purchase_url).and_return('_purchase_url_')

    render_inline(component)
  end

  shared_examples 'plan tracking' do
    it 'has expected tracking attributes' do
      attributes = {
        testid: "upgrade-to-#{plan_name}",
        action: 'click_button',
        label: 'plan_cta',
        property: plan_name
      }
      expect(page).to have_tracking(attributes)
    end
  end

  context 'with free plan' do
    let(:plan_name) { 'free' }

    it 'has header for the current plan' do
      expect(page).to have_content('Your current plan')
      expect(page).to have_selector('.gl-bg-gray-100')
    end

    it 'has pricing info' do
      expect(page).to have_content("#{component.currency_symbol} 0")
      expect(page).not_to have_content('Billed annually')
    end

    it 'does not have cta_link' do
      expect(page).not_to have_link('Learn more')
    end

    context 'with trial as current plan' do
      let(:current_plan_code) { ::Plan::ULTIMATE_TRIAL }

      it 'does not have header for the current plan' do
        expect(page).not_to have_content('Your current plan')
        expect(page).not_to have_selector('.gl-bg-gray-100')
      end
    end
  end

  context 'with premium plan' do
    let(:plan_name) { 'premium' }

    it 'has header for the current plan' do
      expect(page).to have_content('Recommended')
      expect(page).to have_selector('.gl-bg-purple-500')
    end

    it 'has pricing info' do
      expect(page).not_to have_content("#{component.currency_symbol} 0")
      expect(page).to have_content('Billed annually')
    end

    it 'has expected cta_link' do
      expect(page).to have_link('Upgrade to Premium', href: '_purchase_url_', class: 'btn-confirm')
    end

    it 'has primary button as cta' do
      expect(page).to have_selector('.btn-confirm')
      expect(page).not_to have_selector('.btn-confirm-secondary')
    end

    it_behaves_like 'plan tracking'

    context 'with trial as current plan' do
      let(:current_plan_code) { ::Plan::ULTIMATE_TRIAL }

      it 'does not have header for the current plan' do
        expect(page).not_to have_content('Recommended')
        expect(page).not_to have_selector('.header-recommended')
      end

      it 'has outline secondary button as cta' do
        expect(page).to have_selector('.btn-confirm-secondary')
      end
    end
  end

  context 'with ultimate plan' do
    let(:plan_name) { 'ultimate' }

    it 'has pricing info' do
      expect(page).not_to have_content("#{component.currency_symbol} 0")
      expect(page).to have_content('Billed annually')
    end

    it 'has expected cta_link' do
      expect(page).to have_link(
        'Upgrade to Ultimate',
        href: '_purchase_url_',
        class: 'btn-confirm btn-confirm-secondary'
      )
    end

    it 'has outline secondary button as cta' do
      expect(page).to have_selector('.btn-confirm-secondary')
    end

    it_behaves_like 'plan tracking'

    context 'with trial as current plan' do
      let(:current_plan_code) { ::Plan::ULTIMATE_TRIAL }

      it 'has primary button as cta' do
        expect(page).to have_selector('.btn-confirm')
        expect(page).not_to have_selector('.btn-confirm-secondary')
      end
    end
  end

  context 'with unsupported plan' do
    let(:plan_name) { 'bronze' }

    it 'does not render' do
      expect(page).to have_content('')
    end
  end
end
