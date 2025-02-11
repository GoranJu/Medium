# frozen_string_literal: true

module Security
  class SyncPolicyEventWorker
    include Gitlab::EventStore::Subscriber
    include Gitlab::Utils::StrongMemoize

    data_consistency :delayed
    deduplicate :until_executing
    idempotent!

    feature_category :security_policy_management

    # We need to add a delay for batch of projects for groups with
    # a huge number of projects to reduce the pressure on sidekiq.
    PROJECTS_BATCH_SYNC_DELAY = 10.seconds
    SYNC_SERVICE_DELAY_INTERVAL = 1.minute
    PROTECTED_BRANCH_EVENTS = [
      ::Repositories::ProtectedBranchCreatedEvent,
      ::Repositories::ProtectedBranchDestroyedEvent
    ].freeze

    def handle_event(event)
      raise ArgumentError, "Unknown event: #{event.class}" unless PROTECTED_BRANCH_EVENTS.include?(event.class)

      sync_rules(event)
    end

    private

    def sync_rules(event)
      project_or_group = parent(event)

      return unless project_or_group
      return unless project_or_group.licensed_feature_available?(:security_orchestration_policies)

      project_or_group.all_security_orchestration_policy_configurations.each do |configuration|
        if project_or_group.is_a?(Group)
          sync_rules_for_group(configuration, project_or_group, event)
        else
          sync_rules_for_project(configuration, project_or_group, event, SYNC_SERVICE_DELAY_INTERVAL)
        end
      end
    end

    def sync_rules_for_group(configuration, group, event)
      delay = 0
      group.all_project_ids.each_batch do |projects|
        projects.each do |project|
          sync_rules_for_project(configuration, project, event, delay)
        end

        delay += PROJECTS_BATCH_SYNC_DELAY
      end
    end

    def sync_rules_for_project(configuration, project, event, delay)
      if use_approval_policy_rules_for_approval_rules(project)
        sync_rules_for_project_from_read_model(project, event)
      else
        sync_rules_for_project_from_yaml(configuration, project, delay)
      end
    end

    def sync_rules_for_project_from_yaml(configuration, project, delay)
      Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService
        .new(configuration)
        .execute(project.id, { delay: delay })
    end

    def sync_rules_for_project_from_read_model(project, event)
      # A project can have multiple inherited security policy project. But we want to
      # sync from read only once as we already store inherited security policies.
      strong_memoize_with(:sync_rules_for_project_from_read_model, project, event) do
        project.approval_policies.undeleted.find_each do |security_policy|
          Security::SecurityOrchestrationPolicies::SyncPolicyEventService.new(
            project: project,
            security_policy: security_policy,
            event: event
          ).execute
        end
      end
    end

    def use_approval_policy_rules_for_approval_rules(project)
      strong_memoize_with(:use_approval_policy_rules_for_approval_rules, project) do
        Feature.enabled?(:use_approval_policy_rules_for_approval_rules, project)
      end
    end

    def parent(event)
      parent_id = event.data[:parent_id]
      if event.data[:parent_type] == 'project'
        Project.find_by_id(parent_id)
      else
        Group.find_by_id(parent_id)
      end
    end
  end
end
