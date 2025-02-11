# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User creates merge request approval policy", :js, feature_category: :security_policy_management do
  include ListboxHelpers
  include Features::SourceEditorSpecHelpers

  let_it_be(:owner) { create(:user, :with_namespace) }
  let_it_be(:project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:protected_branch) { create(:protected_branch, name: 'spooky-stuff', project: project) }
  let_it_be(:policy_management_project) { create(:project, :repository, namespace: owner.namespace) }
  let(:path_to_policy_editor) { new_project_security_policy_path(project) }
  let(:path_to_merge_request_approval_policy_editor) { "#{path_to_policy_editor}?type=approval_policy" }
  let(:merge_request_approval_policy_with_exceeding_number_of_rules) do
    fixture_file('security_orchestration/merge_request_approval_policy_with_exceeding_number_of_rules.yml', dir: 'ee')
  end

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
    within_testid("approval_policy-card") do
      click_link _('Select policy')
    end
  end

  it "fails to create a policy when user has an incompatible role" do
    fill_in _('Name'), with: 'Missing approvers'

    page.within(find_by_testid('disabled-actions')) do
      select_from_listbox 'Roles', from: 'Choose approver type'
      select_from_listbox 'Developer', from: 'Choose specific role'
    end

    click_button _('Configure with a merge request')

    expect(page).to have_content('Required approvals exceed eligible approvers.')
    expect(page).to have_current_path(path_to_merge_request_approval_policy_editor)
  end

  it_behaves_like 'merge request approval policy invalid policy properties'
end
