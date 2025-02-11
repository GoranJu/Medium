# frozen_string_literal: true

module UpdateOrchestrationPolicyConfiguration
  def update_policy_configuration(configuration)
    configuration.invalidate_policy_yaml_cache

    unless configuration.policy_configuration_valid?
      configuration.delete_all_schedules
      Security::ScanResultPolicies::DeleteScanResultPolicyReadsWorker.perform_async(configuration.id)

      update_configuration_timestamp!(configuration)
      return
    end

    unless configuration.policies_changed?
      update_configuration_timestamp!(configuration)
      return
    end

    Security::PersistSecurityPoliciesWorker.perform_async(configuration.id)
    Security::SecurityOrchestrationPolicies::ComplianceFrameworks::SyncService.new(configuration).execute

    configuration.delete_all_schedules
    configuration.active_scan_execution_policies.each_with_index do |policy, policy_index|
      Security::SecurityOrchestrationPolicies::ProcessRuleService
        .new(policy_configuration: configuration, policy_index: policy_index, policy: policy)
        .execute
    end

    update_configuration_timestamp!(configuration)
  end

  private

  def update_configuration_timestamp!(configuration)
    configuration.update!(configured_at: Time.current)
  end
end
