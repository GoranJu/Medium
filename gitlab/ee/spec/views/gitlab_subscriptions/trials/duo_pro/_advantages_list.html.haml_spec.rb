# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/trials/duo_pro/_advantages_list.html.haml', feature_category: :subscription_management do
  it 'renders the list' do
    render 'gitlab_subscriptions/trials/duo_pro/advantages_list'

    expect(rendered).to have_content(s_("DuoProTrial|GitLab Duo Pro is designed to make teams more efficient " \
                                        "throughout the software development lifecycle with:"))
    expect(rendered).to have_content(s_('DuoProTrial|Code completion and code generation with Code Suggestions'))
    expect(rendered).to have_content(s_('DuoProTrial|Test Generation'))
    expect(rendered).to have_content(s_('DuoProTrial|Code Refactoring'))
    expect(rendered).to have_content(s_('DuoProTrial|Code Explanation'))
    expect(rendered).to have_content(s_('DuoProTrial|Chat within the IDE'))
    expect(rendered).to have_content(s_('DuoProTrial|Organizational user controls'))
    expect(rendered).to have_content(s_("DuoProTrial|GitLab Duo Pro is only available for purchase for Premium and " \
                                        "Ultimate users."))
  end
end
