# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User creates merge request approval policy", :js, feature_category: :security_policy_management do
  include ListboxHelpers
  include Features::SourceEditorSpecHelpers

  let(:path_to_policy_editor) { new_group_security_policy_path(group) }
  let(:path_to_merge_request_approval_policy_editor) { "#{path_to_policy_editor}?type=approval_policy" }
  let_it_be(:owner) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group, owners: owner) }
  let_it_be(:policy_management_project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      security_policy_management_project: policy_management_project,
      namespace: group
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

  it_behaves_like 'merge request approval policy invalid policy properties'
end
