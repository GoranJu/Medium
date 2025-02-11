# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Admin::Projects", feature_category: :groups_and_projects do
  let_it_be_with_reload(:project) { create(:project, :with_namespace_settings) }
  let_it_be(:user) { create(:user) }
  let_it_be(:role) { create(:admin_role, :read_admin_dashboard, user: user) }

  let(:current_user) { user }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(current_user)
    enable_admin_mode!(current_user)

    visit admin_projects_path
  end

  describe "GET /admin/projects" do
    let_it_be(:archived_project) { create :project, :public, :archived }

    context 'when using read_admin_dashboard custom permissions' do
      it_behaves_like 'showing all projects'

      it 'does not have project edit and delete button' do
        page.within('.project-row') do
          expect(page).not_to have_link 'Edit'
          expect(page).not_to have_button 'Delete'
        end
      end
    end
  end

  describe "GET /admin/projects/:namespace_id/:id" do
    let_it_be(:access_request) { create(:project_member, :access_request, project: project) }

    context 'when using read_admin_dashboard custom permissions' do
      before do
        click_link project.name
      end

      it_behaves_like 'showing project details'

      it 'shows access requests without link to manage access' do
        within_testid('access-requests') do
          expect(page).to have_content access_request.user.name
          expect(page).not_to have_link 'Manage access',
            href: project_project_members_path(project, tab: 'access_requests')
        end
      end

      it 'does not show transfer project and repository check sections' do
        expect(page).not_to have_content('Transfer project')
        expect(page).not_to have_content('Repository check')
      end

      it 'does not have project edit' do
        page.within('.content') do
          expect(page).not_to have_link 'Edit'
        end
      end
    end
  end
end
