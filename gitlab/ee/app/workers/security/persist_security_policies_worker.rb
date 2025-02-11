# frozen_string_literal: true

module Security
  class PersistSecurityPoliciesWorker
    include ApplicationWorker

    data_consistency :sticky
    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once
    feature_category :security_policy_management

    def perform(configuration_id)
      configuration = Security::OrchestrationPolicyConfiguration.find_by_id(configuration_id) || return

      configuration.invalidate_policy_yaml_cache

      persist_policy(configuration, configuration.scan_result_policies, :approval_policy)
      persist_policy(configuration, configuration.scan_execution_policy, :scan_execution_policy)
      persist_policy(configuration, configuration.pipeline_execution_policy, :pipeline_execution_policy)
      persist_policy(configuration, configuration.vulnerability_management_policy, :vulnerability_management_policy)
      persist_policy(
        configuration,
        configuration.pipeline_execution_schedule_policy,
        :pipeline_execution_schedule_policy
      )

      Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesService.new(configuration).execute
    end

    private

    def persist_policy(configuration, policies, policy_type)
      Security::SecurityOrchestrationPolicies::PersistPolicyService
        .new(policy_configuration: configuration, policies: policies, policy_type: policy_type)
        .execute
    end
  end
end
