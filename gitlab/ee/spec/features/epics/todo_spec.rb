# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Manually create a todo item from epic', :js, feature_category: :portfolio_management do
  let(:group) { create(:group) }
  let(:epic) { create(:epic, group: group) }
  let(:user) { create(:user) }
  let(:todo_selector) { '[data-testid="sidebar-todo"]' }
  let(:nav_todos_link) { '[data-testid="todos-shortcut-button"]' }

  context 'with notifications_todos_buttons feature flag disabled' do
    before do
      stub_licensed_features(epics: true)
      stub_feature_flags(notifications_todos_buttons: false, namespace_level_work_items: false, work_item_epics: false)

      sign_in(user)
      visit group_epic_path(group, epic)
    end

    it 'creates todo when clicking button' do
      page.within '.issuable-sidebar' do
        click_button 'Add a to-do item'

        expect(page).to have_content 'Mark as done'
      end

      page.within nav_todos_link do
        expect(page).to have_content '1'
      end
    end

    it 'marks a todo as done' do
      page.within '.issuable-sidebar' do
        click_button 'Add a to-do item'
      end

      expect(page).to have_selector(nav_todos_link, visible: true)
      page.within nav_todos_link do
        expect(page).to have_content '1'
      end

      page.within '.issuable-sidebar' do
        click_button 'Mark as done'
      end

      expect(page).to have_selector(nav_todos_link, visible: false)
    end

    it 'passes axe automated accessibility testing for todo' do
      expect(page).to be_axe_clean.within(todo_selector)
    end
  end

  context 'with notifications_todos_buttons feature flag enabled' do
    before do
      stub_licensed_features(epics: true)
      stub_feature_flags(notifications_todos_buttons: true, namespace_level_work_items: false, work_item_epics: false)

      sign_in(user)
      visit group_epic_path(group, epic)
    end

    it 'creates todo when clicking button', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/444882' do
      page.within '.issuable-sidebar' do
        click_button 'Add a to-do item'
        wait_for_requests

        expect(page).to have_selector("button[title='Mark as done']")
      end

      page.within nav_todos_link do
        expect(page).to have_content '1'
      end
    end

    it 'passes axe automated accessibility testing for todo' do
      expect(page).to be_axe_clean.within(todo_selector)
    end
  end
end
