# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial lead submission and creation with multiple eligible namespaces', :saas_trial, :js, feature_category: :acquisition do
  let_it_be(:user) { create(:user) } # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
  let_it_be(:group) do # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
    create(:group, owners: user)
    create(:group, name: 'gitlab', owners: user)
  end

  before_all do
    create(:gitlab_subscription_add_on, :duo_enterprise)
  end

  context 'when creating lead and applying trial is successful' do
    it 'fills out form, submits and lands on the duo page' do
      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      submit_company_information_form

      expect_to_be_on_namespace_selection

      fill_in_trial_selection_form

      submit_trial_selection_form

      expect_to_be_on_gitlab_duo_page
    end

    context 'when new trial is selected from within an existing namespace' do
      it 'fills out form, has the existing namespace preselected, submits and lands on the duo page' do
        glm_params = { glm_source: '_glm_source_', glm_content: '_glm_content_' }

        sign_in(user)

        visit new_trial_path(namespace_id: group.id, **glm_params)

        fill_in_company_information

        submit_company_information_form(extra_params: glm_params)

        expect_to_be_on_namespace_selection

        fill_in_trial_selection_form(from: group.name)

        submit_trial_selection_form(extra_params: glm_params)

        expect_to_be_on_gitlab_duo_page
      end
    end

    context 'when part of the discover security flow' do
      it 'fills out form, submits and lands on the group security dashboard page' do
        sign_in(user)

        visit new_trial_path(glm_content: 'discover-group-security')

        fill_in_company_information

        submit_company_information_form(extra_params: { glm_content: 'discover-group-security' })

        expect_to_be_on_namespace_selection

        fill_in_trial_selection_form

        submit_trial_selection_form(extra_params: { glm_content: 'discover-group-security' })

        expect_to_be_on_group_security_dashboard
      end
    end
  end

  context 'when selecting to create a new group with an existing group name' do
    it 'fills out form, submits and lands on the duo page with a unique path' do
      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      submit_company_information_form

      expect_to_be_on_namespace_selection

      select_from_listbox 'Create group', from: 'Select a group'
      wait_for_requests

      # success
      group_name = 'gitlab1'
      fill_in_trial_selection_form_for_new_group

      submit_new_group_trial_selection_form(extra_params: new_group_attrs(path: group_name))

      expect_to_be_on_gitlab_duo_page(path: group_name)
    end
  end

  context 'when selecting to create a new group with an invalid group name' do
    it 'fills out form, submits and is presented with error then fills out valid name' do
      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      submit_company_information_form

      expect_to_be_on_namespace_selection

      select_from_listbox 'Create group', from: 'Select a group'
      wait_for_requests

      # namespace invalid check
      fill_in_trial_selection_form_for_new_group(name: '_invalid group name_')

      click_button 'Activate my trial'

      expect_to_have_namespace_creation_errors

      # success when choosing a valid name instead
      group_name = 'valid'
      fill_in_trial_selection_form_for_new_group(name: group_name)

      submit_new_group_trial_selection_form(extra_params: new_group_attrs(path: group_name, name: group_name))

      expect_to_be_on_gitlab_duo_page(path: group_name, name: group_name)
    end
  end

  context 'when applying lead fails' do
    it 'fills out form, submits and sent back to information form with errors and is then resolved' do
      # setup
      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      # lead failure
      submit_company_information_form(lead_result: lead_failure)

      expect_to_be_on_lead_form_with_errors

      # success
      submit_company_information_form

      expect_to_be_on_namespace_selection

      fill_in_trial_selection_form

      submit_trial_selection_form

      expect_to_be_on_gitlab_duo_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent to select namespace with errors and is then resolved' do
      # setup
      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      submit_company_information_form

      expect_to_be_on_namespace_selection

      fill_in_trial_selection_form

      # trial failure
      submit_trial_selection_form(result: trial_failure)

      expect_to_be_on_namespace_selection_with_errors

      # success
      fill_in_trial_selection_form(from: group.name)

      submit_trial_selection_form

      expect_to_be_on_gitlab_duo_page
    end
  end

  def fill_in_trial_selection_form_for_new_group(name: 'gitlab')
    within_testid('trial-form') do
      expect(page).to have_text('New group name')
    end

    fill_in_trial_form_for_new_group(name: name)
  end
end
