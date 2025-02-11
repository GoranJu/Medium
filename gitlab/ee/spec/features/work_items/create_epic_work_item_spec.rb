# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create epic work item', :js, feature_category: :team_planning do
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public, developers: user) }

  context 'when on group work items list' do
    before do
      stub_licensed_features(epics: true, epic_colors: true, issuable_health_status: true, subepics: true)
      sign_in(user)
      visit group_epics_path(group)
    end

    context 'when "New epic" button is clicked' do
      before do
        click_link 'New epic'
      end

      it 'creates an epic work item', :aggregate_failures do
        within_modal do
          # check all the widgets are rendered
          expect(page).to have_selector('[data-testid="work-item-description-wrapper"]')
          expect(page).to have_selector('[data-testid="work-item-assignees"]')
          expect(page).to have_selector('[data-testid="work-item-labels"]')
          expect(page).to have_selector('[data-testid="work-item-rolledup-dates"]')
          expect(page).to have_selector('[data-testid="work-item-health-status"]')
          expect(page).to have_selector('[data-testid="work-item-color"]')
          expect(page).to have_selector('[data-testid="work-item-parent"]')

          send_keys 'I am a new epic'
          click_button 'Create epic'
          page.refresh
        end

        expect(page).to have_link 'I am a new epic'
        expect(page).to have_css '[data-testid="epic-icon"]'
      end
    end
  end
end
