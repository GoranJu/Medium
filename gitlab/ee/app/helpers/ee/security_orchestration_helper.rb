# frozen_string_literal: true

module EE::SecurityOrchestrationHelper
  def can_update_security_orchestration_policy_project?(container)
    can?(current_user, :update_security_orchestration_policy_project, container)
  end

  def can_modify_security_policy?(container)
    can?(current_user, :modify_security_policy, container)
  end

  def assigned_policy_project(container)
    return unless container&.security_orchestration_policy_configuration

    orchestration_policy_configuration = container.security_orchestration_policy_configuration
    security_policy_management_project = orchestration_policy_configuration.security_policy_management_project

    {
      id: security_policy_management_project.to_global_id.to_s,
      name: security_policy_management_project.name,
      full_path: security_policy_management_project.full_path,
      branch: security_policy_management_project.default_branch_or_main
    }
  end

  def orchestration_policy_data(container, policy_type = nil, policy = nil, approvers = nil)
    return unless container

    disable_scan_policy_update = !can_modify_security_policy?(container)

    policy_data = {
      assigned_policy_project: assigned_policy_project(container).to_json,
      disable_scan_policy_update: disable_scan_policy_update.to_s,
      namespace_id: container.id,
      namespace_path: container.full_path,
      policies_path: security_policies_path(container),
      policy: policy&.to_json,
      policy_editor_empty_state_svg_path: image_path('illustrations/monitoring/unable_to_connect.svg'),
      policy_type: policy_type,
      role_approver_types: Security::ScanResultPolicy::ALLOWED_ROLES,
      scan_policy_documentation_path: help_page_path('user/application_security/policies/_index.md'),
      action_approvers: approvers&.to_json,
      software_licenses: software_licenses,
      global_group_approvers_enabled: Gitlab::CurrentSettings.security_policy_global_group_approvers_enabled.to_json,
      root_namespace_path: container.root_ancestor&.full_path,
      timezones: timezone_data(format: :full).to_json,
      max_active_scan_execution_policies_reached: max_active_scan_execution_policies_reached?(container).to_s,
      max_active_scan_result_policies_reached: max_active_scan_result_policies_reached?(container).to_s,
      max_scan_result_policies_allowed: scan_result_policies_limit,
      max_scan_execution_policies_allowed: Security::ScanExecutionPolicy::POLICY_LIMIT,
      max_ci_component_publishing_policies_allowed: Security::CiComponentPublishingPolicy::POLICY_LIMIT,
      max_ci_component_publishing_policies_reached: max_active_ci_component_publishing_policies_reached?(container)
                                                      .to_s,
      max_active_pipeline_execution_policies_reached: max_active_pipeline_execution_policies_reached?(container).to_s,
      max_pipeline_execution_policies_allowed: Security::PipelineExecutionPolicy::POLICY_LIMIT,
      max_active_vulnerability_management_policies_reached:
        max_active_vulnerability_management_policies_reached?(container).to_s,
      max_vulnerability_management_policies_allowed: Security::VulnerabilityManagementPolicy::POLICY_LIMIT,
      max_scan_execution_policy_actions: max_scan_execution_policy_actions
    }

    if container.is_a?(::Project)
      policy_data.merge(
        create_agent_help_path: help_page_url('user/clusters/agent/install/_index.md')
      )
    else
      policy_data
    end
  end

  def security_policies_path(container)
    container.is_a?(::Project) ? project_security_policies_path(container) : group_security_policies_path(container)
  end

  def max_active_scan_execution_policies_reached?(container)
    active_scan_execution_policy_count(container) >= Security::ScanExecutionPolicy::POLICY_LIMIT
  end

  def max_active_pipeline_execution_policies_reached?(container)
    active_pipeline_execution_policy_count(container) >= Security::PipelineExecutionPolicy::POLICY_LIMIT
  end

  def active_pipeline_execution_policy_count(container)
    container
      &.security_orchestration_policy_configuration
      &.active_pipeline_execution_policies
      &.length || 0
  end

  def active_scan_execution_policy_count(container)
    container
      &.security_orchestration_policy_configuration
      &.active_scan_execution_policies
      &.length || 0
  end

  def max_active_ci_component_publishing_policies_reached?(container)
    active_ci_component_publishing_policy_count(container) >= Security::CiComponentPublishingPolicy::POLICY_LIMIT
  end

  def active_ci_component_publishing_policy_count(container)
    container
      &.security_orchestration_policy_configuration
      &.active_ci_component_publishing_policies
      &.length || 0
  end

  def max_active_vulnerability_management_policies_reached?(container)
    active_vulnerability_management_policy_count(container) >= Security::VulnerabilityManagementPolicy::POLICY_LIMIT
  end

  def active_vulnerability_management_policy_count(container)
    container
      &.security_orchestration_policy_configuration
      &.active_vulnerability_management_policies
      &.length || 0
  end

  def max_active_scan_result_policies_reached?(container)
    active_scan_result_policy_count(container) >= scan_result_policies_limit
  end

  def scan_result_policies_limit
    Gitlab::CurrentSettings.security_approval_policies_limit
  end

  def active_scan_result_policy_count(container)
    container
      &.security_orchestration_policy_configuration
      &.active_scan_result_policies
      &.length || 0
  end

  def max_scan_execution_policy_actions
    Gitlab::CurrentSettings.scan_execution_policies_action_limit
  end

  def breadcrumb_by_type(policy_type)
    policy_types_map = {
      "approval_policy" => s_("SecurityOrchestration|New merge request approval policy"),
      "scan_result_policy" => s_("SecurityOrchestration|New merge request approval policy"),
      "scan_execution_policy" => s_("SecurityOrchestration|New scan execution policy"),
      "pipeline_execution_policy" => s_("SecurityOrchestration|New pipeline execution policy"),
      "vulnerability_management_policy" => s_("SecurityOrchestration|New vulnerability management policy")
    }

    policy_types_map.fetch(policy_type.to_s, s_("SecurityOrchestration|New policy"))
  end

  def security_configurations_preventing_project_deletion(project)
    return ::Security::OrchestrationPolicyConfiguration.none unless ::Feature.enabled?(
      :reject_security_policy_project_deletion, project)

    unless project.licensed_feature_available?(:security_orchestration_policies)
      return ::Security::OrchestrationPolicyConfiguration.none
    end

    ::Security::OrchestrationPolicyConfiguration.for_management_project(project)
  end

  def security_configurations_preventing_group_deletion(group)
    unless ::Feature.enabled?(:reject_security_policy_project_deletion_groups, group) &&
        group.licensed_feature_available?(:security_orchestration_policies)
      return ::Security::OrchestrationPolicyConfiguration.none
    end

    ::Security::OrchestrationPolicyConfiguration.for_management_project(group.all_project_ids)
  end

  private

  def software_licenses
    if Feature.enabled?(:static_licenses) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
      ::Gitlab::SPDX::Catalogue.latest_active_license_names
    else
      SoftwareLicense.all_license_names
    end
  end
end
