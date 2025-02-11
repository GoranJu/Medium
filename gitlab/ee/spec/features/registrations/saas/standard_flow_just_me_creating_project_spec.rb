# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Standard flow for user picking just me and creating a project', :js, :saas_registration, :with_current_organization, feature_category: :onboarding do
  where(:case_name, :sign_up_method) do
    [
      ['with regular sign up', -> { regular_sign_up }],
      ['with sso sign up', -> { sso_sign_up }]
    ]
  end

  with_them do
    it 'registers the user and creates a group and project reaching onboarding', :sidekiq_inline do
      sign_up_method.call

      expect_to_see_welcome_form
      expect_to_send_iterable_request

      fills_in_welcome_form
      click_on 'Continue'

      expect_to_see_group_and_project_creation_form

      fills_in_group_and_project_creation_form
      click_on 'Create project'

      expect_to_be_in_learn_gitlab
    end
  end

  context 'when template was selected' do
    context 'when your_work_projects_vue feature flag is enabled' do
      it 'creates a project from given template', :sidekiq_inline do
        regular_sign_up

        expect_to_see_welcome_form
        expect_to_send_iterable_request

        fills_in_welcome_form
        click_on 'Continue'

        expect_to_see_group_and_project_creation_form

        fills_in_group_and_project_creation_form
        selects_project_template
        click_on 'Create project'

        expect_to_be_in_learn_gitlab

        visit root_path
        click_on 'Member'
        click_on 'Test Project'

        expect(page).to have_content("Initialized from 'NodeJS Express' project template")
      end
    end

    context 'when your_work_projects_vue feature flag is disabled' do
      before do # rubocop:disable Gitlab/RSpec/AvoidSetup -- we need to disable this feature flag just for this spec
        stub_feature_flags(your_work_projects_vue: false)
      end

      it 'creates a project from given template', :sidekiq_inline do
        regular_sign_up

        expect_to_see_welcome_form
        expect_to_send_iterable_request

        fills_in_welcome_form
        click_on 'Continue'

        expect_to_see_group_and_project_creation_form

        fills_in_group_and_project_creation_form
        selects_project_template
        click_on 'Create project'

        expect_to_be_in_learn_gitlab

        visit root_path
        click_on 'Test Project'

        expect(page).to have_content("Initialized from 'NodeJS Express' project template")
      end
    end
  end

  def fills_in_welcome_form
    select 'Software Developer', from: 'user_onboarding_status_role'
    select 'A different reason', from: 'user_onboarding_status_registration_objective'
    fill_in 'Why are you signing up? (optional)', with: 'My reason'

    choose 'Just me'
    choose 'Create a new project'
  end

  def selects_project_template
    click_on 'Select'
    find_by_testid('listbox-item-express').click
  end

  def expect_to_see_welcome_form
    expect(page).to have_content('Welcome to GitLab, Registering!')

    page.within(welcome_form_selector) do
      expect(page).to have_content('Role')
      expect(page).to have_field('user_onboarding_status_role', valid: false)
      expect(page).to have_field('user_setup_for_company_true', valid: false)
      expect(page).to have_content('I\'m signing up for GitLab because:')
      expect(page).to have_content('Who will be using GitLab?')
      expect(page)
        .to have_content(_('Enables a free Ultimate + GitLab Duo Enterprise trial when you create a new project.'))
      expect(page).to have_content('What would you like to do?')
    end
  end
end
