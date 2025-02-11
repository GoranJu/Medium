# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial lead submission and creation with one eligible namespace', :saas_trial, :js, feature_category: :plan_provisioning do
  let_it_be(:user) { create(:user) } # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
  let_it_be_with_reload(:group) { create(:group_with_plan, name: 'gitlab', owners: user) } # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group

  before_all do
    create(:gitlab_subscription_add_on, :duo_enterprise)
  end

  context 'when creating lead and applying trial is successful' do
    it 'fills out form, submits and lands on the duo page' do
      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      submit_single_namespace_trial_company_form(with_trial: true)

      expect_to_be_on_gitlab_duo_page
    end

    context 'on a premium plan' do
      it 'fills out form, submits and lands on the group page' do
        group.gitlab_subscription.update!(hosted_plan_id: create(:premium_plan).id)

        sign_in(user)

        visit new_trial_path

        fill_in_company_information

        submit_single_namespace_trial_company_form(with_trial: true)

        expect_to_be_on_gitlab_duo_page(path: group.name)
      end
    end

    context 'on a free plan and has previously had a legacy ultimate trial' do
      it 'fills out form, submits and lands on the group page' do
        group.gitlab_subscription.update!(
          trial: true,
          trial_starts_on: 1.month.ago,
          trial_ends_on: 10.days.ago
        )

        sign_in(user)

        visit new_trial_path

        fill_in_company_information

        submit_single_namespace_trial_company_form(with_trial: true)

        expect_to_be_on_gitlab_duo_page(path: group.name)
      end
    end

    context 'on a premium plan and has previously had a legacy ultimate trial' do
      it 'fills out form, submits and lands on the group page' do
        group.gitlab_subscription.update!(
          hosted_plan_id: create(:premium_plan).id,
          trial: true,
          trial_starts_on: 1.month.ago,
          trial_ends_on: 10.days.ago
        )

        sign_in(user)

        visit new_trial_path

        fill_in_company_information

        submit_single_namespace_trial_company_form(with_trial: true)

        expect_to_be_on_gitlab_duo_page(path: group.name)
      end
    end

    context 'when part of the discover security flow' do
      it 'fills out form, submits and lands on the group security dashboard page' do
        sign_in(user)

        visit new_trial_path(glm_content: 'discover-group-security')

        fill_in_company_information

        submit_single_namespace_trial_company_form(
          with_trial: true,
          extra_params: { glm_content: 'discover-group-security' }
        )

        expect_to_be_on_group_security_dashboard
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
      submit_single_namespace_trial_company_form(lead_result: lead_failure)

      expect_to_be_on_lead_form_with_errors

      # success
      submit_single_namespace_trial_company_form(with_trial: true)

      expect_to_be_on_gitlab_duo_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent to select namespace with errors and is then resolved' do
      # setup
      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      # trial failure
      submit_single_namespace_trial_company_form(with_trial: true, trial_result: trial_failure)

      expect_to_be_on_namespace_selection_with_errors

      # success
      fill_in_trial_selection_form(group_select: false)

      submit_trial_selection_form

      expect_to_be_on_gitlab_duo_page
    end

    it 'fails submitting trial and then chooses to create a namespace and apply trial to it' do
      # setup
      sign_in(user)

      visit new_trial_path

      fill_in_company_information

      # trial failure
      submit_single_namespace_trial_company_form(with_trial: true, trial_result: trial_failure)

      expect_to_be_on_namespace_selection_with_errors

      # user pivots and decides to create a new group instead of using existing
      select_from_listbox 'Create group', from: 'gitlab'
      wait_for_requests

      fill_in_trial_form_for_new_group

      # success
      group_name = 'gitlab1'
      submit_new_group_trial_selection_form(extra_params: new_group_attrs(path: group_name))

      expect_to_be_on_gitlab_duo_page(path: group_name)
    end
  end

  def submit_single_namespace_trial_company_form(**kwargs)
    submit_company_information_form(**kwargs, button_text: 'Activate my trial')
  end
end
