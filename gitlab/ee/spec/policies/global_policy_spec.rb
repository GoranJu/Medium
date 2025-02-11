# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GlobalPolicy, feature_category: :shared do
  include ExternalAuthorizationServiceHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:admin) { create(:admin) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

  subject { described_class.new(current_user, [user]) }

  describe 'reading operations dashboard' do
    context 'when licensed' do
      before do
        stub_licensed_features(operations_dashboard: true)
      end

      it { is_expected.to be_allowed(:read_operations_dashboard) }

      context 'and the user is not logged in' do
        let(:current_user) { nil }

        it { is_expected.to be_disallowed(:read_operations_dashboard) }
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(operations_dashboard: false)
      end

      it { is_expected.to be_disallowed(:read_operations_dashboard) }
    end
  end

  describe 'access_workspaces_feature ability' do
    where(:anonymous, :licensed, :allowed) do
      # anonymous  | licensed  | allowed
      true         | true      | false
      false        | false     | false
      true         | false     | false
      false        | true      | true
    end

    with_them do
      let(:current_user) { anonymous ? nil : user }

      before do
        stub_licensed_features(remote_development: licensed)
      end

      it { is_expected.to(allowed ? be_allowed(:access_workspaces_feature) : be_disallowed(:access_workspace_feature)) }
    end

    context 'when anon=false and licensed=true it is allowed' do
      # TODO: This is a redundant test because the TableSyntax test above was giving false positives.
      #       See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/136642#note_1670763898

      let(:current_user) { user }

      before do
        stub_licensed_features(remote_development: true)
      end

      it { is_expected.to be_allowed(:access_workspaces_feature) }
    end
  end

  it { is_expected.to be_disallowed(:read_licenses) }
  it { is_expected.to be_disallowed(:destroy_licenses) }
  it { is_expected.to be_disallowed(:read_all_geo) }
  it { is_expected.to be_disallowed(:read_all_workspaces) }
  it { is_expected.to be_disallowed(:manage_subscription) }
  it { is_expected.to be_disallowed(:read_cloud_connector_status) }
  it { is_expected.to be_disallowed(:read_admin_subscription) }

  context 'when admin mode enabled', :enable_admin_mode do
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_licenses) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:destroy_licenses) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_all_geo) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_all_workspaces) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:manage_subscription) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_cloud_connector_status) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_admin_subscription) }
  end

  context 'when admin mode disabled' do
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_licenses) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:destroy_licenses) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_all_geo) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_all_workspaces) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:manage_subscription) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_cloud_connector_status) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_admin_subscription) }
  end

  shared_examples 'analytics policy' do |action|
    context 'anonymous user' do
      let(:current_user) { nil }

      it 'is not allowed' do
        is_expected.to be_disallowed(action)
      end
    end

    context 'authenticated user' do
      it 'is allowed' do
        is_expected.to be_allowed(action)
      end
    end
  end

  describe 'view_productivity_analytics' do
    include_examples 'analytics policy', :view_productivity_analytics
  end

  describe 'update_max_pages_size' do
    context 'when feature is enabled' do
      before do
        stub_licensed_features(pages_size_limit: true)
      end

      it { is_expected.to be_disallowed(:update_max_pages_size) }

      context 'when admin mode enabled', :enable_admin_mode do
        it { expect(described_class.new(admin, [user])).to be_allowed(:update_max_pages_size) }
      end

      context 'when admin mode disabled' do
        it { expect(described_class.new(admin, [user])).to be_disallowed(:update_max_pages_size) }
      end
    end

    it { expect(described_class.new(admin, [user])).to be_disallowed(:update_max_pages_size) }
  end

  describe 'create_group_with_default_branch_protection' do
    context 'for an admin' do
      let(:current_user) { admin }

      context 'when the `default_branch_protection_restriction_in_groups` feature is available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: true)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.to be_disallowed(:create_group_with_default_branch_protection) }
          end
        end
      end

      context 'when the `default_branch_protection_restriction_in_groups` feature is not available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: false)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end
      end
    end

    context 'for a normal user' do
      let(:current_user) { create(:user) }

      context 'when the `default_branch_protection_restriction_in_groups` feature is available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: true)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_disallowed(:create_group_with_default_branch_protection) }
        end
      end

      context 'when the `default_branch_protection_restriction_in_groups` feature is not available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: false)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end
      end
    end
  end

  describe 'list_removable_projects' do
    context 'when user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { admin }

      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: licensed?)
      end

      context 'when licensed feature is enabled' do
        let(:licensed?) { true }

        it { is_expected.to be_allowed(:list_removable_projects) }
      end

      context 'when licensed feature is not enabled' do
        let(:licensed?) { false }

        it { is_expected.to be_disallowed(:list_removable_projects) }
      end
    end

    context 'when user is a normal user' do
      let_it_be(:current_user) { create(:user) }

      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: licensed?)
      end

      context 'when licensed feature is enabled' do
        let(:licensed?) { true }

        it { is_expected.to be_allowed(:list_removable_projects) }
      end

      context 'when licensed feature is not enabled' do
        let(:licensed?) { false }

        it { is_expected.to be_disallowed(:list_removable_projects) }
      end
    end
  end

  describe 'custom roles' do
    describe 'admin_member_role' do
      let(:permissions) { [:admin_member_role, :read_admin_member_role] }

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it { is_expected.to be_disallowed(*permissions) }

        context 'when admin mode enabled', :enable_admin_mode do
          let(:current_user) { admin }

          it { is_expected.to be_allowed(*permissions) }
        end

        context 'when admin mode disabled' do
          let(:current_user) { admin }

          it { is_expected.to be_disallowed(*permissions) }
        end
      end

      context 'when custom_roles feature is disabled' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_disallowed(*permissions) }
        end
      end
    end

    describe 'view_member_roles' do
      let(:permissions) { [:view_member_roles] }

      where(license: [:custom_roles, :default_roles_assignees])

      with_them do
        context 'when feature is enabled' do
          before do
            stub_licensed_features(license => true)
          end

          it { is_expected.to be_disallowed(*permissions) }

          context 'when admin mode enabled', :enable_admin_mode do
            let(:current_user) { admin }

            it { is_expected.to be_allowed(*permissions) }
          end

          context 'when admin mode disabled' do
            let(:current_user) { admin }

            it { is_expected.to be_disallowed(*permissions) }
          end
        end

        context 'when feature is disabled' do
          let(:current_user) { admin }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_disallowed(*permissions) }
          end
        end
      end
    end

    describe 'read_member_role' do
      let(:permissions) { [:read_member_role] }

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'for anynomous user' do
          let(:current_user) { nil }

          it { is_expected.to be_disallowed(*permissions) }
        end

        context 'for registeres user' do
          let(:current_user) { user }

          it { is_expected.to be_allowed(*permissions) }
        end
      end

      context 'when custom_roles feature is disabled' do
        context 'when admin mode enabled', :enable_admin_mode do
          it { expect(described_class.new(admin, [user])).to be_disallowed(*permissions) }
        end
      end
    end
  end

  describe ':export_user_permissions', :enable_admin_mode do
    let(:policy) { :export_user_permissions }

    let_it_be(:admin) { build_stubbed(:admin) }
    let_it_be(:guest) { build_stubbed(:user) }

    where(:role, :licensed, :allowed) do
      :admin | true | true
      :admin | false | false
      :guest | true | false
      :guest | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        stub_licensed_features(export_user_permissions: licensed)
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe 'create_group_via_api' do
    let(:policy) { :create_group_via_api }

    context 'on .com' do
      before do
        allow(::Gitlab).to receive(:com?).and_return(true)
      end

      context 'when feature is enabled' do
        before do
          stub_feature_flags(top_level_group_creation_enabled: true)
        end

        it { is_expected.to be_allowed(policy) }
      end

      context 'when feature is disabled' do
        before do
          stub_feature_flags(top_level_group_creation_enabled: false)
        end

        it { is_expected.to be_disallowed(policy) }
      end
    end

    context 'on self-managed' do
      context 'when feature is enabled' do
        before do
          stub_feature_flags(top_level_group_creation_enabled: true)
        end

        it { is_expected.to be_allowed(policy) }
      end

      context 'when feature is disabled' do
        before do
          stub_feature_flags(top_level_group_creation_enabled: false)
        end

        it { is_expected.to be_allowed(policy) }
      end
    end
  end

  describe ':view_instance_devops_adoption & :manage_devops_adoption_namespaces', :enable_admin_mode do
    let(:current_user) { admin }

    context 'when license does not include the feature' do
      before do
        stub_licensed_features(instance_level_devops_adoption: false)
      end

      it { is_expected.to be_disallowed(:view_instance_devops_adoption, :manage_devops_adoption_namespaces) }
    end

    context 'when feature is enabled and license include the feature' do
      before do
        stub_licensed_features(instance_level_devops_adoption: true)
      end

      it { is_expected.to be_allowed(:view_instance_devops_adoption, :manage_devops_adoption_namespaces) }

      context 'for non-admins' do
        let(:current_user) { user }

        it { is_expected.to be_disallowed(:view_instance_devops_adoption, :manage_devops_adoption_namespaces) }
      end
    end

    context 'when feature is enabled through usage ping features' do
      before do
        stub_usage_ping_features(true)
      end

      it { is_expected.to be_allowed(:view_instance_devops_adoption, :manage_devops_adoption_namespaces) }

      context 'for non-admins' do
        let(:current_user) { user }

        it { is_expected.to be_disallowed(:view_instance_devops_adoption, :manage_devops_adoption_namespaces) }
      end
    end
  end

  describe 'read_runner_usage' do
    include AdminModeHelper

    where(:licensed, :is_admin, :enable_admin_mode, :clickhouse_configured, :expected) do
      true  | true  | true  | true  | true
      false | true  | true  | true  | false
      true  | false | true  | true  | false
      true  | true  | false | true  | false
      true  | true  | true  | false | false
    end

    with_them do
      before do
        stub_licensed_features(runner_performance_insights: licensed)

        enable_admin_mode!(admin) if enable_admin_mode

        allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(clickhouse_configured)
      end

      let(:current_user) { is_admin ? admin : user }

      it 'matches expectation' do
        if expected
          is_expected.to be_allowed(:read_runner_usage)
        else
          is_expected.to be_disallowed(:read_runner_usage)
        end
      end
    end
  end

  describe 'read_jobs_statistics' do
    context 'when feature is enabled' do
      before do
        stub_licensed_features(runner_performance_insights: true)
      end

      it { is_expected.to be_disallowed(:read_jobs_statistics) }

      context 'when admin mode enabled', :enable_admin_mode do
        it { expect(described_class.new(admin, [user])).to be_allowed(:read_jobs_statistics) }
      end

      context 'when admin mode disabled' do
        it { expect(described_class.new(admin, [user])).to be_disallowed(:read_jobs_statistics) }
      end
    end

    context 'when feature is disabled' do
      before do
        stub_licensed_features(runner_performance_insights: false)
      end

      context 'when admin mode enabled', :enable_admin_mode do
        it { expect(described_class.new(admin, [user])).to be_disallowed(:read_jobs_statistics) }
      end
    end
  end

  describe 'read_runner_upgrade_status' do
    it { is_expected.to be_disallowed(:read_runner_upgrade_status) }

    context 'when runner_upgrade_management is available' do
      before do
        stub_licensed_features(runner_upgrade_management: true)
      end

      it { is_expected.to be_allowed(:read_runner_upgrade_status) }
    end

    context 'when user has paid namespace' do
      before do
        allow(Gitlab).to receive(:com?).and_return true
        group = create(:group_with_plan, plan: :ultimate_plan)
        group.add_maintainer(user)
      end

      it { expect(described_class.new(user, nil)).to be_allowed(:read_runner_upgrade_status) }
    end
  end

  describe 'admin_service_accounts' do
    subject { described_class.new(admin, [user]) }

    it { is_expected.to be_disallowed(:admin_service_accounts) }

    context 'when feature is enabled' do
      before do
        stub_licensed_features(service_accounts: true)
      end

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:admin_service_accounts) }
      end

      context 'when admin mode disabled' do
        it { is_expected.to be_disallowed(:admin_service_accounts) }
      end
    end
  end

  describe 'admin_instance_external_audit_events' do
    let_it_be(:admin) { create(:admin) }
    let_it_be(:user) { create(:user) }

    shared_examples 'admin external events is not allowed' do
      context 'when user is instance admin' do
        context 'when admin mode enabled', :enable_admin_mode do
          it { expect(described_class.new(admin, nil)).to be_disallowed(:admin_instance_external_audit_events) }
        end

        context 'when admin mode disabled' do
          it { expect(described_class.new(admin, nil)).to be_disallowed(:admin_instance_external_audit_events) }
        end
      end

      context 'when user is not instance admin' do
        it { expect(described_class.new(user, nil)).to be_disallowed(:admin_instance_external_audit_events) }
      end
    end

    context 'when licence is enabled' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      context 'when user is instance admin' do
        context 'when admin mode enabled', :enable_admin_mode do
          it { expect(described_class.new(admin, nil)).to be_allowed(:admin_instance_external_audit_events) }
        end

        context 'when admin mode disabled' do
          it { expect(described_class.new(admin, nil)).to be_disallowed(:admin_instance_external_audit_events) }
        end
      end

      context 'when user is not instance admin' do
        it { expect(described_class.new(user, nil)).to be_disallowed(:admin_instance_external_audit_events) }
      end
    end

    context 'when licence is not enabled' do
      it_behaves_like 'admin external events is not allowed'
    end
  end

  describe 'access_code_suggestions' do
    let(:policy) { :access_code_suggestions }

    let_it_be_with_reload(:current_user) { create(:user) }

    where(:code_suggestions_licensed, :duo_pro_seat_assigned, :self_hosted_enabled, :self_hosted_licensed,
      :code_suggestions_enabled_for_user) do
      true  | true  | true  | true   |  be_allowed(:access_code_suggestions)
      true  | true  | false | false  |  be_allowed(:access_code_suggestions)
      true  | false | true  | true   |  be_allowed(:access_code_suggestions)
      true  | false | true  | false  |  be_disallowed(:access_code_suggestions)
      true  | false | false | false  |  be_disallowed(:access_code_suggestions)
      false | true  | true  | true   |  be_disallowed(:access_code_suggestions)
      false | false | false | false  |  be_disallowed(:access_code_suggestions)
    end

    with_them do
      before do
        stub_licensed_features(code_suggestions: code_suggestions_licensed)

        # This is needed to allow responding differently based on the arguments. We make the default throw an error
        # to check we don't get unexpected calls.
        # See https://rspec.info/features/3-12/rspec-mocks/setting-constraints/matching-arguments/
        allow(current_user).to receive(:allowed_to_use?).and_raise(StandardError)

        allow(current_user).to receive(:allowed_to_use?).with(:code_suggestions).and_return(duo_pro_seat_assigned)
        allow(::Ai::FeatureSetting).to receive(:code_suggestions_self_hosted?).and_return(:self_hosted_enabled)
        allow(current_user).to receive(:allowed_to_use?)
          .with(:code_suggestions, service_name: :self_hosted_models).and_return(self_hosted_licensed)
      end

      it { is_expected.to code_suggestions_enabled_for_user }
    end
  end

  describe 'access_duo_chat' do
    let(:policy) { :access_duo_chat }

    let_it_be_with_reload(:current_user) { create(:user) }

    context 'when on .org or .com', :saas do
      where(:duo_pro_seat_assigned, :duo_chat_enabled_for_user) do
        true  | be_allowed(policy)
        false | be_disallowed(policy)
      end

      with_them do
        before do
          duo_chat_service_data = instance_double(CloudConnector::SelfSigned::AvailableServiceData)
          allow(CloudConnector::AvailableServices).to receive(:find_by_name).with(:duo_chat).and_return(
            duo_chat_service_data
          )
          allow(duo_chat_service_data).to receive(:allowed_for?).with(current_user).and_return(duo_pro_seat_assigned)
        end

        it { is_expected.to duo_chat_enabled_for_user }
      end
    end

    context 'when not on .org or .com' do
      where(:lock_duo_features_enabled, :duo_pro_seat_assigned, :duo_chat_enabled_for_user) do
        true | true | be_disallowed(policy)
        true  |  false |  be_disallowed(policy)
        false |  false |  be_disallowed(policy)
        false |  true  |  be_allowed(policy)
      end

      with_them do
        before do
          allow(::Gitlab).to receive(:org_or_com?).and_return(false)
          stub_ee_application_setting(lock_duo_features_enabled: lock_duo_features_enabled)
          duo_chat_service_data = instance_double(CloudConnector::SelfSigned::AvailableServiceData)
          allow(CloudConnector::AvailableServices).to receive(:find_by_name).with(:duo_chat).and_return(
            duo_chat_service_data
          )
          allow(duo_chat_service_data).to receive(:allowed_for?).with(current_user).and_return(duo_pro_seat_assigned)
        end

        it { is_expected.to duo_chat_enabled_for_user }
      end
    end

    context 'when duo chat is self hosted' do
      where(:duo_chat_on_saas, :self_hosted, :allowed_to_use, :free, :duo_chat_enabled_for_user) do
        true  | true  | true  | true  | be_allowed(policy)
        false | true  | true  | true  | be_allowed(policy)
        true  | false | true  | true  | be_allowed(policy)
        true  | true  | false | true  | be_disallowed(policy)
        true  | true  | true  | false | be_allowed(policy)
      end

      with_them do
        before do
          allow(::Gitlab::Saas).to receive(:feature_available?).with(:duo_chat_on_saas).and_return(duo_chat_on_saas)
          allow(::Ai::FeatureSetting).to receive_message_chain(:find_by_feature,
            :self_hosted?).and_return(self_hosted)

          self_hosted_service_data = instance_double(CloudConnector::SelfSigned::AvailableServiceData)
          duo_chat_service_data = instance_double(CloudConnector::SelfSigned::AvailableServiceData)
          allow(CloudConnector::AvailableServices).to receive(:find_by_name).with(:self_hosted_models)
                                                                            .and_return(self_hosted_service_data)
          allow(CloudConnector::AvailableServices).to receive(:find_by_name).with(:duo_chat)
                                                                            .and_return(duo_chat_service_data)
          allow(duo_chat_service_data).to receive(:allowed_for?).with(current_user).and_return(allowed_to_use)
          allow(self_hosted_service_data).to receive(:allowed_for?).with(current_user).and_return(allowed_to_use)
          allow(self_hosted_service_data).to receive(:free_access?).and_return(free)
        end

        it { is_expected.to duo_chat_enabled_for_user }
      end
    end

    context 'when amazon q is connected' do
      where(:duo_chat_on_saas, :amazon_q_connected, :allowed_to_use, :ff_enabled, :duo_chat_enabled_for_user) do
        true  | true  | true  | true  | be_allowed(policy)
        true  | true  | true  | false | be_disallowed(policy)
        false | true  | true  | true  | be_allowed(policy)
        true  | false | true  | true  | be_disallowed(policy)
        true  | false | false | true  | be_disallowed(policy)
        true  | true  | false | true  | be_disallowed(policy)
      end

      with_them do
        before do
          allow(::Gitlab::Saas).to receive(:feature_available?).with(:duo_chat_on_saas).and_return(duo_chat_on_saas)

          Ai::Setting.instance.update!(amazon_q_ready: amazon_q_connected)
          stub_licensed_features(ai_chat: true, amazon_q: true)
          stub_feature_flags(amazon_q_chat_and_code_suggestions: ff_enabled)

          allow(current_user).to receive(:allowed_to_use?).with(:duo_chat, service_name: :amazon_q_integration,
            licensed_feature: :amazon_q).and_return(allowed_to_use)
        end

        it { is_expected.to duo_chat_enabled_for_user }
      end
    end
  end

  describe 'access_x_ray_on_instance' do
    context 'when on .org or .com', :saas do
      context 'when x ray available' do
        before do
          stub_saas_features(code_suggestions_x_ray: true)
        end

        it { is_expected.to be_allowed(:access_x_ray_on_instance) }
      end

      context 'when x ray not available' do
        before do
          stub_saas_features(code_suggestions_x_ray: false)
        end

        context 'when code suggestions available' do
          before do
            stub_licensed_features(code_suggestions: true)
          end

          it { is_expected.to be_allowed(:access_x_ray_on_instance) }
        end

        context 'when code suggestions not available' do
          before do
            stub_licensed_features(code_suggestions: false)
          end

          it { is_expected.to be_disallowed(:access_x_ray_on_instance) }
        end
      end
    end

    context 'when not on .org or .com' do
      context 'when code suggestions available' do
        before do
          stub_licensed_features(code_suggestions: true)
        end

        it { is_expected.to be_allowed(:access_x_ray_on_instance) }
      end

      context 'when code suggestions not available' do
        it { is_expected.to be_disallowed(:access_x_ray_on_instance) }
      end
    end
  end

  describe 'git access' do
    context 'security policy bot' do
      let(:current_user) { security_policy_bot }

      it { is_expected.to be_allowed(:access_git) }
    end
  end

  describe 'explain git commands' do
    let(:policy) { :access_glab_ask_git_command }

    where(:duo_features_enabled, :allowed_to_use, :enabled_for_user) do
      true | false | be_disallowed(:access_glab_ask_git_command)
      false | true | be_disallowed(:access_glab_ask_git_command)
      true | true | be_allowed(:access_glab_ask_git_command)
    end

    with_them do
      before do
        stub_application_setting(duo_features_enabled: duo_features_enabled)

        allow(current_user).to receive(:allowed_to_use?)
          .with(:glab_ask_git_command, licensed_feature: :glab_ask_git_command).and_return(allowed_to_use)
      end

      it { is_expected.to enabled_for_user }
    end
  end

  describe 'manage self-hosted AI models' do
    let(:current_user) { admin }
    let(:license_double) { instance_double('License', ultimate?: true) }

    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active) }

    before do
      allow(License).to receive(:current).and_return(license_double)
    end

    context 'when admin' do
      context 'when conditions are respected', :enable_admin_mode do
        it { is_expected.to be_allowed(:manage_self_hosted_models_settings) }
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(:manage_self_hosted_models_settings) }
      end

      context 'when license is not an Ultimate license', :enable_admin_mode do
        let(:license_double) { instance_double('License', ultimate?: false) }

        it { is_expected.to be_disallowed(:manage_self_hosted_models_settings) }
      end

      context 'when there is no active Duo Enterprise subscription', :enable_admin_mode do
        before do
          add_on_purchase.update!(expires_on: 1.day.ago)
        end

        it { is_expected.to be_disallowed(:manage_self_hosted_models_settings) }
      end

      context 'when instance is in SASS mode', :enable_admin_mode do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          stub_feature_flags(allow_self_hosted_features_for_com: true)
        end

        it { is_expected.to be_allowed(:manage_self_hosted_models_settings) }

        context 'when allow_self_hosted_features_for_com is disabled' do
          before do
            stub_feature_flags(allow_self_hosted_features_for_com: false)
          end

          it { is_expected.to be_disallowed(:manage_self_hosted_models_settings) }
        end
      end
    end

    context 'when regular user' do
      it { is_expected.to be_disallowed(:manage_self_hosted_models_settings) }
    end
  end

  context 'custom permissions' do
    where(:custom_ability, :enabled_permissions) do
      :read_admin_cicd         | %i[read_admin_cicd]
      :read_admin_dashboard    | %i[read_admin_dashboard access_admin_area]
      :read_admin_monitoring   | %i[read_admin_audit_log]
      :read_admin_subscription | %i[read_admin_subscription read_billable_member read_licenses]
      :read_admin_users        | %i[read_admin_users]
    end

    with_them do
      context 'when a user is assigned an admin custom role' do
        let!(:role) { create(:admin_role, custom_ability, user: current_user) }

        context 'when custom_roles feature is enabled' do
          before do
            stub_licensed_features(custom_roles: true)
          end

          it { is_expected.to be_allowed(*enabled_permissions) }
        end

        context 'when custom_roles feature is disabled' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it { is_expected.to be_disallowed(*enabled_permissions) }
        end
      end
    end
  end
end
