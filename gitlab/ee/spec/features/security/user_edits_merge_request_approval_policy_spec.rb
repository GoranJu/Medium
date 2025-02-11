# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User edits merge request approval policy", :js, feature_category: :security_policy_management do
  include ListboxHelpers

  let_it_be(:owner) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group, owners: owner) }
  let_it_be(:project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:protected_branch) { create(:protected_branch, name: 'spooky-stuff', project: project) }
  let_it_be(:policy_management_project) { create(:project, :repository, owners: owner) }

  let_it_be(:policy_yaml) do
    Gitlab::Config::Loader::Yaml.new(fixture_file('security_orchestration/merge_request_approval_policy.yml',
      dir: 'ee')).load!
  end

  before do
    allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |policy|
      allow(policy).to receive_messages(policy_configuration_valid?: true, policy_hash: policy_yaml,
        policy_last_updated_at: Time.current)
    end

    sign_in(owner)
    stub_licensed_features(security_orchestration_policies: true)
  end

  shared_examples "user edits existing merge request approval policy" do
    it "fails to save existing policy without name field" do
      within_testid('policies-list') do
        find_by_testid('base-dropdown-toggle', match: :first).click
        click_link 'Edit'
      end

      fill_in _('Name'), with: ''

      click_button _('Configure with a merge request')

      expect(page).to have_content('Empty policy name')
    end
  end

  describe 'group policy' do
    let!(:policy_configuration) do
      create(
        :security_orchestration_policy_configuration,
        :namespace,
        security_policy_management_project: policy_management_project,
        namespace: group
      )
    end

    before do
      visit(group_security_policies_path(group))
    end

    it_behaves_like 'user edits existing merge request approval policy'
  end

  describe 'project policy' do
    let!(:policy_configuration) do
      create(
        :security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: project
      )
    end

    before do
      visit(project_security_policies_path(project))
    end

    it_behaves_like 'user edits existing merge request approval policy'
  end
end
