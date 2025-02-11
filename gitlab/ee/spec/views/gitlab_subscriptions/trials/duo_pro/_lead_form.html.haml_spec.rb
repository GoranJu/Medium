# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/trials/duo_pro/_lead_form.html.haml', feature_category: :subscription_management do
  let(:user) { build_stubbed(:user) }

  before do
    allow(view).to receive(:current_user) { user }
    allow(GitlabSubscriptions::Trials).to receive(:single_eligible_namespace?).and_return(true)
  end

  it 'renders lead form general items' do
    render 'gitlab_subscriptions/trials/duo_pro/lead_form'

    expect(rendered).to have_content(s_('DuoProTrial|Start your free GitLab Duo Pro trial'))
    expect(rendered).to have_content(s_('DuoProTrial|We just need some additional information to activate your trial.'))
    expect(rendered).to render_template('gitlab_subscriptions/trials/duo_pro/_advantages_list')
  end

  context 'when group_name is defined' do
    before do
      assign(:group_name, '_some_group_')
    end

    it 'renders lead form' do
      render 'gitlab_subscriptions/trials/duo_pro/lead_form'

      expect(rendered).to have_content('Start your free GitLab Duo Pro trial on _some_group_')
    end
  end

  context 'when group_name is not defined' do
    it 'renders lead form' do
      render 'gitlab_subscriptions/trials/duo_pro/lead_form'

      expect(rendered).to have_content('Start your free GitLab Duo Pro trial')
      expect(rendered).not_to have_content('Start your free GitLab Duo Pro trial on')
    end
  end
end
