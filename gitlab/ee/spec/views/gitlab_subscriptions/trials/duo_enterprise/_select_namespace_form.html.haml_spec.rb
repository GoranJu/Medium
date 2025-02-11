# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/trials/duo_enterprise/_select_namespace_form.html.haml', feature_category: :subscription_management do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group) }

  before do
    allow(view).to receive(:current_user) { user }
    assign(:eligible_namespaces, [group])
  end

  it 'renders select namespace form' do
    render 'gitlab_subscriptions/trials/duo_enterprise/select_namespace_form'

    expect(rendered)
      .to have_content(s_('DuoEnterpriseTrial|Apply your GitLab Duo Enterprise trial to an existing group'))

    expect(rendered).to render_template('gitlab_subscriptions/trials/duo_enterprise/_advantages_list')
  end
end
