# frozen_string_literal: true

module ConstructSecurityPolicies
  extend ActiveSupport::Concern
  include Security::SecurityOrchestrationPolicies::DeprecatedPropertiesChecker

  POLICY_YAML_ATTRIBUTES = %i[name description enabled actions rules approval_settings policy_scope
    fallback_behavior metadata policy_tuning].freeze

  def construct_vulnerability_management_policies(policies)
    policies.map do |policy|
      {
        name: policy[:name],
        description: policy[:description],
        edit_path: edit_path(policy, :vulnerability_management_policy),
        enabled: policy[:enabled],
        policy_scope: policy_scope(policy[:policy_scope]),
        yaml: YAML.dump(
          policy.slice(:name, :description, :enabled, :rules, :actions, :policy_scope).deep_stringify_keys
        ),
        updated_at: policy[:config].policy_last_updated_at,
        source: {
          project: policy[:project],
          namespace: policy[:namespace],
          inherited: policy[:inherited]
        }
      }
    end
  end

  def construct_pipeline_execution_policies(policies)
    policies.map do |policy|
      warnings = []
      {
        name: policy[:name],
        description: policy[:description],
        edit_path: edit_path(policy, :pipeline_execution_policy),
        policy_blob_file_path: policy_blob_file_path(policy, warnings),
        enabled: policy[:enabled],
        policy_scope: policy_scope(policy[:policy_scope]),
        yaml: YAML.dump(
          policy.slice(:name, :description, :enabled, :pipeline_config_strategy, :content, :policy_scope, :metadata,
            :suffix, :skip_ci).deep_stringify_keys
        ),
        updated_at: policy[:config].policy_last_updated_at,
        source: {
          project: policy[:project],
          namespace: policy[:namespace],
          inherited: policy[:inherited]
        },
        warnings: warnings
      }
    end
  end

  def construct_scan_execution_policies(policies)
    policies.map do |policy|
      {
        name: policy[:name],
        description: policy[:description],
        edit_path: edit_path(policy, :scan_execution_policy),
        enabled: policy[:enabled],
        policy_scope: policy_scope(policy[:policy_scope]),
        yaml: YAML.dump(policy.slice(*POLICY_YAML_ATTRIBUTES, :skip_ci).deep_stringify_keys),
        updated_at: policy[:config].policy_last_updated_at,
        deprecated_properties: deprecated_properties(policy),
        source: {
          project: policy[:project],
          namespace: policy[:namespace],
          inherited: policy[:inherited]
        }
      }
    end
  end

  def construct_scan_result_policies(policies)
    policies.map do |policy|
      approvers = approvers(policy)
      scan_result_policy = {
        name: policy[:name],
        description: policy[:description],
        edit_path: edit_path(policy, :approval_policy),
        enabled: policy[:enabled],
        policy_scope: policy_scope(policy[:policy_scope]),
        yaml: YAML.dump(policy.slice(*POLICY_YAML_ATTRIBUTES).deep_stringify_keys),
        updated_at: policy[:config].policy_last_updated_at,
        user_approvers: approvers[:users],
        action_approvers: approvers[:approvers],
        all_group_approvers: approvers[:all_groups],
        role_approvers: approvers[:roles],
        custom_roles: approvers[:custom_roles],
        deprecated_properties: deprecated_properties(policy),
        source: {
          project: policy[:project],
          namespace: policy[:namespace],
          inherited: policy[:inherited]
        }
      }

      scan_result_policy
    end
  end

  def approvers(policy)
    Security::SecurityOrchestrationPolicies::FetchPolicyApproversService
      .new(policy: policy, container: container, current_user: current_user)
      .execute
  end

  def policy_scope(scope_yaml)
    Security::SecurityOrchestrationPolicies::PolicyScopeFetcher
      .new(policy_scope: scope_yaml, container: container, current_user: current_user)
      .execute
  end

  def container
    object
  end

  def edit_path(policy, type)
    id = CGI.escape(policy[:name])
    if policy[:namespace]
      Rails.application.routes.url_helpers.edit_group_security_policy_url(
        policy[:namespace], id: id, type: type
      )
    else
      Rails.application.routes.url_helpers.edit_project_security_policy_url(
        policy[:project], id: id, type: type
      )
    end
  end

  def policy_blob_file_path(policy, warnings)
    project = pipeline_execution_policy_content_project(policy)
    if project
      content_include = policy.dig(:content, :include, 0)
      file = content_include[:file]
      ref = content_include[:ref] || project.default_branch_or_main
      Gitlab::Routing.url_helpers.project_blob_path(project, File.join(ref, file))
    else
      warnings << _('The policy is associated with a non-existing Pipeline configuration file.')
      ""
    end
  end

  def pipeline_execution_policy_content_project(policy)
    content_include = policy.dig(:content, :include, 0)
    Project.find_by_full_path(content_include[:project])
  end
end
