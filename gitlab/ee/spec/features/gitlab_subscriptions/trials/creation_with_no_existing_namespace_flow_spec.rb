# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial lead submission, group and trial creation', :with_current_organization, :saas_trial, :js, feature_category: :acquisition do
  let_it_be(:user) { create(:user, organizations: [current_organization]) } # rubocop:disable Gitlab/RSpec/AvoidSetup -- We need to ensure user is member of current organization

  before_all do
    create(:gitlab_subscription_add_on, :duo_enterprise)
  end

  context 'when creating lead, group and applying trial is successful' do
    it 'fills out form, testing validations, submits and lands on the duo page' do
      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      submit_company_information_form

      expect_to_be_on_namespace_creation

      click_button 'Activate my trial'

      # required field check
      expect(page).to have_native_text_validation_message('new_group_name')

      # namespace invalid check
      fill_in_trial_form_for_new_group(name: '_invalid group name_')

      click_button 'Activate my trial'

      expect_to_be_on_namespace_creation
      expect_to_have_namespace_creation_errors

      # namespace filled out with blank spaces
      fill_in_trial_form_for_new_group(name: '  ')

      click_button 'Activate my trial'

      expect_to_be_on_namespace_creation
      expect_to_have_namespace_creation_errors(group_name: '  ', error_message: "Name can't be blank")

      # success
      fill_in_trial_form_for_new_group

      submit_new_group_trial_selection_form(extra_params: new_group_attrs)

      expect_to_be_on_gitlab_duo_page
    end

    context 'when part of the discover security flow' do
      it 'fills out form, submits and lands on the group security dashboard page' do
        sign_in(user)

        visit new_trial_path(glm_content: 'discover-group-security')

        fill_in_company_information

        submit_company_information_form(extra_params: { glm_content: 'discover-group-security' })

        expect_to_be_on_namespace_creation

        fill_in_trial_form_for_new_group

        submit_new_group_trial_selection_form(
          extra_params: { glm_content: 'discover-group-security', **new_group_attrs }
        )

        expect_to_be_on_group_security_dashboard(group_for_path: Group.last)
      end
    end

    context 'when source of the trial initiation is about.gitlab.com' do
      it 'fills out form without the company question, submits and lands on the duo page' do
        glm_source = 'about.gitlab.com'

        sign_in(user)

        visit new_trial_path(glm_source: glm_source)

        fill_in_company_information

        submit_company_information_form(extra_params: { glm_source: glm_source })

        expect_to_be_on_namespace_creation_without_company_question

        fill_in_trial_form_for_new_group

        submit_new_group_trial_selection_form(extra_params: { glm_source: glm_source, **new_group_attrs })

        expect_to_be_on_gitlab_duo_page
      end
    end

    context 'when source of the trial initiation is not a gitlab domain' do
      it 'fills out form, submits and lands on the duo page' do
        glm_source = '_some_other_source_'

        sign_in(user)

        visit new_trial_path(glm_source: glm_source)

        fill_in_company_information

        submit_company_information_form(extra_params: { glm_source: glm_source })

        expect_to_be_on_namespace_creation

        fill_in_trial_form_for_new_group

        submit_new_group_trial_selection_form(extra_params: { glm_source: glm_source, **new_group_attrs })

        expect_to_be_on_gitlab_duo_page
      end
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

      expect_to_be_on_namespace_creation

      fill_in_trial_form_for_new_group

      submit_new_group_trial_selection_form(extra_params: new_group_attrs)

      expect_to_be_on_gitlab_duo_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent to select namespace with errors and is then resolved' do
      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      submit_company_information_form

      expect_to_be_on_namespace_creation

      fill_in_trial_form_for_new_group

      # trial failure
      submit_new_group_trial_selection_form(result: trial_failure, extra_params: new_group_attrs)

      expect_to_be_on_namespace_selection_with_errors

      # success
      submit_new_group_trial_selection_form(extra_params: new_group_attrs)

      expect_to_be_on_gitlab_duo_page
    end
  end

  context 'when user cannot create groups' do
    it 'fails and redirects to not found' do
      user.update_attribute(:can_create_group, false)

      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      submit_company_information_form

      expect_to_be_on_namespace_creation

      fill_in_trial_form_for_new_group

      click_button 'Activate my trial'

      expect(page).to have_content('Page not found')
    end
  end

  def expect_to_be_on_namespace_creation
    expect(page).to have_content('New group name')
    expect(page).not_to have_content('This trial is for')
  end

  def expect_to_be_on_namespace_creation_without_company_question
    expect(page).to have_content('New group name')
    expect(page).not_to have_content('This trial is for')
  end
end
