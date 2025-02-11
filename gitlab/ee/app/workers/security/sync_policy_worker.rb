# frozen_string_literal: true

module Security
  class SyncPolicyWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :sticky

    deduplicate :until_executing, including_scheduled: true
    idempotent!

    feature_category :security_policy_management

    def handle_event(event)
      security_policy_id = event.data[:security_policy_id]
      policy = Security::Policy.find_by_id(security_policy_id) || return

      case event
      when Security::PolicyCreatedEvent
        handle_create_event(policy)
      when Security::PolicyUpdatedEvent
        handle_update_event(policy, event.data)
      when Security::PolicyDeletedEvent
        ::Security::DeleteSecurityPolicyWorker.perform_async(security_policy_id)
      end
    end

    private

    def handle_create_event(policy)
      return unless policy.enabled

      sync_pipeline_execution_policy_metadata(policy)
      all_project_ids(policy).each do |project_id|
        ::Security::SyncProjectPolicyWorker.perform_async(project_id, policy.id, {})
      end
    end

    def handle_update_event(policy, event_data)
      policy_diff = Security::SecurityOrchestrationPolicies::PolicyDiff::Diff.from_json(
        event_data[:diff], event_data[:rules_diff]
      )

      sync_pipeline_execution_policy_metadata(policy) if policy_diff.content_changed?
      return unless policy_diff.needs_refresh? || policy_diff.needs_rules_refresh?

      all_project_ids(policy).each do |project_id|
        ::Security::SyncProjectPolicyWorker.perform_async(project_id, policy.id, event_data)
      end
    end

    def all_project_ids(policy)
      policy.security_orchestration_policy_configuration.all_project_ids
    end

    def sync_pipeline_execution_policy_metadata(policy)
      return if ::Feature.disabled?(:pipeline_execution_policy_analyze_configs, policy.namespace)
      return unless policy.type_pipeline_execution_policy?

      config_project_id = policy.security_pipeline_execution_policy_config_link&.project_id
      return unless config_project_id

      ::Security::SyncPipelineExecutionPolicyMetadataWorker
        .perform_async(
          config_project_id,
          policy.security_orchestration_policy_configuration.policy_last_updated_by&.id,
          policy.content['content'],
          [policy.id])
    end
  end
end
