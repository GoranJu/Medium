# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Statistics, 'Statistics', :aggregate_failures, feature_category: :devops_reports do
  describe 'GET /application/statistics' do
    let_it_be(:user) { create(:user) }

    subject(:get_statistics) { get api('/application/statistics', user) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when user is allowed to access_admin_area thanks to custom role' do
      let_it_be(:role) { create(:admin_role, :read_admin_dashboard, user: user) }

      it 'returns success' do
        get_statistics

        expect(response).to have_gitlab_http_status(:success)
      end

      context 'when custom_ability_read_admin_dashboard FF is disabled' do
        before do
          stub_feature_flags(custom_ability_read_admin_dashboard: false)
        end

        it "returns forbidden error" do
          get_statistics

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when user can not access admin area' do
      it 'returns forbidden error' do
        get_statistics

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
