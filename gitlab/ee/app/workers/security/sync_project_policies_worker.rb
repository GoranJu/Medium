# frozen_string_literal: true

module Security
  class SyncProjectPoliciesWorker
    include ApplicationWorker

    data_consistency :sticky

    deduplicate :until_executing, including_scheduled: true
    idempotent!
    feature_category :security_policy_management

    concurrency_limit -> { 200 }

    def perform(project_id, policy_configuration_id)
      project = Project.find_by_id(project_id)
      policy_configuration = Security::OrchestrationPolicyConfiguration.find_by_id(policy_configuration_id)

      return unless project && policy_configuration

      policy_configuration.security_policies.undeleted.find_each do |security_policy|
        Security::SecurityOrchestrationPolicies::SyncProjectService.new(
          security_policy: security_policy, project: project, policy_changes: {}
        ).execute
      end
    end
  end
end
