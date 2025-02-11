# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/_form.html.haml', feature_category: :user_management do
  let(:namespace) { build(:group) }
  let(:user) { build(:user, namespace: namespace) }

  before do
    assign(:user, user)
  end

  context 'for namespace plan' do
    context 'when gitlab_com_subscriptions SaaS feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'renders licensed features' do
        render

        expect(rendered).to have_text('Licensed Features')
      end

      it 'has plan related fields', :saas do
        build(:gitlab_subscription, namespace: namespace)

        render

        expect(rendered).to have_testid('plan-dropdown')
      end
    end

    context 'when gitlab_com_subscriptions SaaS feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not render licensed features' do
        render

        expect(rendered).not_to have_text('Licensed Features')
      end
    end
  end
end
