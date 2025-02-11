# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ApplicationSettings::RolesAndPermissionsController, :enable_admin_mode, feature_category: :user_management do
  let_it_be(:role_id) { Gitlab::Access.options.each_key.first }
  let_it_be(:admin) { create(:admin) }

  shared_examples 'not found' do
    it 'is not found' do
      get_method

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'access control' do |licenses|
    context 'with non-admin user' do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      it_behaves_like 'not found'
    end

    context 'when no user is logged in' do
      it 'redirects to login page' do
        get_method

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end

    context 'with an admin user' do
      before do
        sign_in(admin)
      end

      context 'when no suitable license is available' do
        it_behaves_like 'not found'
      end

      context 'when a suitable license is available' do
        using RSpec::Parameterized::TableSyntax

        where(license: licenses)

        with_them do
          before do
            stub_licensed_features(license => true)
          end

          it 'returns a 200 status code' do
            get_method

            expect(response).to have_gitlab_http_status(:ok)
          end

          context 'when on SaaS' do
            before do
              stub_saas_features(gitlab_com_subscriptions: true)
            end

            it_behaves_like 'not found'
          end
        end
      end
    end
  end

  shared_examples 'role existence check' do
    before do
      sign_in(admin)
      stub_licensed_features(custom_roles: true)
    end

    context 'with a valid custom role' do
      it 'returns a 200 status code' do
        get_method

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the ID is for a non-existent custom role' do
      let_it_be(:role_id) { non_existing_record_id }

      it_behaves_like 'not found'
    end

    context 'when the ID is for a non-existent standard role' do
      let_it_be(:role_id) { 'NONEXISTENT_ROLE' }

      it_behaves_like 'not found'
    end

    context 'when the ID is for the minimal access role' do
      let_it_be(:role_id) { 'MINIMAL_ACCESS' }

      it_behaves_like 'not found'
    end
  end

  describe 'GET #index' do
    subject(:get_method) { get admin_application_settings_roles_and_permissions_path }

    it_behaves_like 'access control', [:custom_roles, :default_roles_assignees]
  end

  describe 'GET #show' do
    subject(:get_method) { get admin_application_settings_roles_and_permission_path(role_id) }

    it_behaves_like 'access control', [:custom_roles, :default_roles_assignees]
    it_behaves_like 'role existence check'
  end

  describe 'GET #edit' do
    subject(:get_method) { get edit_admin_application_settings_roles_and_permission_path(role_id) }

    it_behaves_like 'access control', [:custom_roles]
    it_behaves_like 'role existence check'
  end
end
