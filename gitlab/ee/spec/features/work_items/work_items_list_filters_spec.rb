# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work items list filters', :js, feature_category: :team_planning do
  include FilteredSearchHelpers
  include WorkItemFeedbackHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group, developers: user) }

  let_it_be(:incident) { create(:incident, project: project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:task) { create(:work_item, :task, project: project) }
  let_it_be(:test_case) { create(:quality_test_case, project: project) }

  context 'for signed in user' do
    before do
      stub_licensed_features(quality_management: true)
      sign_in(user)
      visit group_work_items_path(group)

      close_work_item_feedback_popover_if_present
    end

    describe 'type' do
      it 'filters', :aggregate_failures do
        select_tokens 'Type', 'Issue', submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(issue.title)

        click_button 'Clear'

        select_tokens 'Type', 'Incident', submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(incident.title)

        click_button 'Clear'

        select_tokens 'Type', 'Test case', submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(test_case.title)

        click_button 'Clear'

        select_tokens 'Type', 'Task', submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(task.title)
      end
    end
  end
end
