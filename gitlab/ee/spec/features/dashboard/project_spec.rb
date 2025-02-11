# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dashboard projects', feature_category: :groups_and_projects do
  let_it_be(:user) { create :user }
  let_it_be(:group) { create :group }

  before_all do
    group.add_owner(user)
  end

  context 'when deletion is adjourned' do
    before do
      stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      sign_in(user)
    end

    let_it_be(:project) { create(:project, :archived, namespace: group, marked_for_deletion_at: Date.current) }

    context 'when your_work_projects_vue feature flag is enabled' do
      it 'renders Restore button', :js do
        visit inactive_dashboard_projects_path
        wait_for_requests

        within_testid("projects-list-item-#{project.id}") do
          click_button 'Actions'
          expect(page).to have_button('Restore')
        end
      end
    end

    context 'when your_work_projects_vue feature flag is disabled' do
      before do
        stub_feature_flags(your_work_projects_vue: false)
        sign_in(user)
      end

      it 'renders Restore button' do
        visit removed_dashboard_projects_path

        expect(page).to have_link('Restore', href: project_restore_path(project))
      end
    end
  end
end
