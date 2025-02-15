# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User creates scan execution policy", :js, feature_category: :security_policy_management do
  include Features::SourceEditorSpecHelpers
  include ListboxHelpers

  let_it_be(:owner) { create(:user, :with_namespace) }
  let_it_be(:project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:path_to_policy_editor) { new_project_security_policy_path(project) }
  let_it_be(:protected_branch) { create(:protected_branch, name: 'spooky-stuff', project: project) }
  let_it_be(:policy_management_project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: project
    )
  end

  before do
    sign_in(owner)
    stub_feature_flags(security_policies_split_view: false)
    stub_licensed_features(security_orchestration_policies: true)
    visit(path_to_policy_editor)
    within_testid("scan_execution_policy-card") do
      click_link _('Select policy')
    end
  end

  it "can create a valid policy when a policy project exists" do
    fill_in _('Name'), with: 'Run secret detection scan on every branch'
    click_button _('Configure with a merge request')
    expect(page).to have_current_path(project_merge_request_path(policy_management_project, 1))
  end

  it "cannot create an invalid policy" do
    click_button _('Configure with a merge request')
    expect(page).to have_current_path("#{path_to_policy_editor}?type=scan_execution_policy")
    expect(page).to have_text(_('Empty policy name'))
  end
end
