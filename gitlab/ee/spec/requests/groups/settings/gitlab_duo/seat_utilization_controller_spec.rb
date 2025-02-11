# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabDuo::SeatUtilizationController, type: :request, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  subject(:get_index) { get group_settings_gitlab_duo_seat_utilization_index_path(group) }

  before do
    stub_licensed_features(code_suggestions: true)
    add_on = create(:gitlab_subscription_add_on)
    create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: group, add_on: add_on)
    sign_in(user)
  end

  context 'when user has read_usage_quotas permission' do
    before_all do
      group.add_owner(user)
    end

    context "when show_gitlab_duo_settings_app? returns false" do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it "renders 404" do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context "when show_gitlab_duo_settings_app? returns true" do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it "renders index with 200 status code" do
        get_index

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end

    context 'when in a subgroup' do
      let(:subgroup) { create(:group, :private, parent: group) }

      before do
        subgroup.add_owner(user)
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it "renders 404" do
        get group_settings_gitlab_duo_seat_utilization_index_path(subgroup)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  context 'when user does not have read_usage_quotas permission' do
    before do
      group.add_maintainer(user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- cannot use stub_saas_features in before_all
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it "renders 404" do
      get_index

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end
end
