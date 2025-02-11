# frozen_string_literal: true

module Security
  class SyncProjectPolicyWorker
    include ApplicationWorker

    data_consistency :sticky
    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once

    concurrency_limit -> { 200 }

    feature_category :security_policy_management

    # This is needed to ensure that the worker does not run multiple times for the same security policy
    # when there is an already existing job that handles a different update from policy_chages.
    def self.idempotency_arguments(arguments)
      project_id, security_policy_id, _ = arguments

      [project_id, security_policy_id]
    end

    def perform(project_id, security_policy_id, policy_changes)
      project = Project.find_by_id(project_id)
      security_policy = Security::Policy.find_by_id(security_policy_id)

      return unless project && security_policy

      Security::SecurityOrchestrationPolicies::SyncProjectService.new(
        security_policy: security_policy,
        project: project,
        policy_changes: policy_changes.deep_symbolize_keys
      ).execute
    end
  end
end
