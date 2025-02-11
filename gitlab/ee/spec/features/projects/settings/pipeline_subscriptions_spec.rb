# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project Subscriptions',
  feature_category: :continuous_integration do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:upstream_project) { create(:project, :public, :repository) }
  let_it_be(:downstream_project) { create(:project, :public, :repository, upstream_projects: [project]) }
  let_it_be(:user) { create(:user) }

  before_all do
    project.add_maintainer(user)
    upstream_project.add_maintainer(user)
    downstream_project.add_maintainer(user)
  end

  before do
    stub_licensed_features(ci_project_subscriptions: true)
    stub_feature_flags(pipeline_subscriptions_vue: false)

    sign_in(user)
    visit project_settings_ci_cd_path(project)
  end

  it 'renders the correct path for the form action' do
    within '#pipeline-subscriptions' do
      click_on 'Add new'
      form_action = find('#pipeline-subscriptions-form')['action']

      expect(form_action).to end_with("/#{project.full_path}/-/subscriptions")
    end
  end

  it 'renders the list of downstream projects' do
    within_testid('downstream-project-subscriptions') do
      expect(find_by_testid('crud-count').text).to eq '1'
    end

    expect(page).to have_content(downstream_project.name)
    expect(page).to have_content(downstream_project.owner.name)
  end

  it 'doesn\'t allow to delete downstream projects' do
    within_testid('downstream-project-subscriptions') do
      expect(page).not_to have_content('[data-testid="delete-subscription"]')
    end
  end

  it 'successfully creates new pipeline subscription',
    quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/444886' do
    within '#pipeline-subscriptions' do
      click_on 'Add new'
      within 'form' do
        fill_in 'upstream_project_path', with: upstream_project.full_path

        click_on 'Subscribe'
      end

      within_testid('upstream-project-subscriptions') do
        expect(find_by_testid('crud-count').text).to eq '1'
      end

      expect(page).to have_content(upstream_project.name)
      expect(page).to have_content(upstream_project.namespace.name)
    end

    expect(page).to have_content('Subscription successfully created.')
  end

  it 'shows flash warning when unsuccessful in creating a pipeline subscription',
    quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/469604' do
    within '#pipeline-subscriptions' do
      click_on 'Add new'
      within 'form' do
        fill_in 'upstream_project_path', with: 'wrong/path'

        click_on 'Subscribe'
      end

      within_testid('upstream-project-subscriptions') do
        expect(find_by_testid('crud-count').text).to eq '0'
        expect(page).to have_content('This project is not subscribed to any project pipelines.')
      end
    end

    expect(page).to have_content('This project path either does not exist or you do not have access.')
  end

  it 'subscription is removed successfully', :js, quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/438106' do
    within '#pipeline-subscriptions' do
      click_on 'Add new'
      within 'form' do
        fill_in 'upstream_project_path', with: upstream_project.full_path

        click_on 'Subscribe'
      end
    end

    find_by_testid('delete-subscription').click
    click_button 'OK'

    expect(page).to have_content('Subscription successfully deleted.')
  end
end
