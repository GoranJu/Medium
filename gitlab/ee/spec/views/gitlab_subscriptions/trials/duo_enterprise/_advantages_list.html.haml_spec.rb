# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/trials/duo_enterprise/_advantages_list.html.haml', feature_category: :subscription_management do
  it 'renders the list' do
    render 'gitlab_subscriptions/trials/duo_enterprise/advantages_list'

    expect(rendered).to have_content('GitLab Duo Enterprise is is your end-to-end AI partner')
    expect(rendered).to have_content('Stay on top of regulatory requirements')
    expect(rendered).to have_content('Enhance security and remediate')
    expect(rendered).to have_content('Quickly remedy broken pipelines')
    expect(rendered).to have_content('Gain deeper insights')
    expect(rendered).to have_content('Maintain control')
    expect(rendered).to have_content('GitLab Duo Enterprise is only available')
  end
end
