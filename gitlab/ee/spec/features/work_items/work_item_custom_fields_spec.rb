# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work Item Custom Fields', :js, feature_category: :team_planning do
  let_it_be(:group) { create(:group, path: 'gitlab-org') } # Must be gitlab-org for mock data
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:work_item) { create(:work_item, project: project) }

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_feature_flags(custom_fields_feature: true)
    stub_feature_flags(work_items_alpha: true) # Required for mockWidgets

    sign_in(user)
  end

  context 'when custom fields feature is enabled' do
    it 'displays number type custom field correctly' do
      visit project_work_item_path(project, work_item)
      wait_for_requests

      within_testid('work-item-custom-field') do
        expect(page).to have_text('Number custom field label')
        expect(page).to have_text('5')
      end
    end

    it 'displays text type custom field correctly' do
      visit project_work_item_path(project, work_item)
      wait_for_requests

      within_testid('work-item-custom-field') do
        expect(page).to have_text('Text custom field label')
        expect(page).to have_text('some text')
      end
    end

    it 'displays single select custom field correctly' do
      visit project_work_item_path(project, work_item)
      wait_for_requests

      within_testid('work-item-custom-field') do
        expect(page).to have_text('Single select custom field label')
        expect(page).to have_text('Option 1')
      end
    end

    it 'displays multi select custom field correctly' do
      visit project_work_item_path(project, work_item)
      wait_for_requests

      within_testid('work-item-custom-field') do
        expect(page).to have_text('Multi select custom field label')
        expect(page).to have_text('Option 1')
        expect(page).to have_text('Option 2')
      end
    end

    it 'displays fields as read-only for users without update permissions' do
      project.add_guest(user)
      visit project_work_item_path(project, work_item)
      wait_for_requests

      within_testid('work-item-custom-field') do
        all('input').each do |input|
          expect(input['disabled']).to eq('true')
        end
      end
    end
  end

  context 'when custom fields feature is disabled' do
    it 'does not display custom fields section' do
      stub_feature_flags(custom_fields_feature: false)
      visit project_work_item_path(project, work_item)
      wait_for_requests

      expect(page).not_to have_selector('[data-testid="work-item-custom-field"]')
    end
  end
end
