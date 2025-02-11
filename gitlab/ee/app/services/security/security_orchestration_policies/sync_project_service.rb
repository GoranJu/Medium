# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncProjectService < BaseProjectPolicyService
      def initialize(security_policy:, project:, policy_changes:)
        super(security_policy: security_policy, project: project)
        @policy_changes = policy_changes
      end

      def execute
        if policy_diff.any_changes?
          # Existing policy has been changed.
          sync_policy_changes
        else
          # Policy has just been created, link it.
          link_policy
        end
      end

      private

      attr_reader :policy_changes

      def policy_diff
        Security::SecurityOrchestrationPolicies::PolicyDiff::Diff.from_json(
          policy_changes[:diff], policy_changes[:rules_diff]
        )
      end
      strong_memoize_attr :policy_diff

      def sync_policy_changes
        return unlink_policy if should_unlink_policy?
        return link_policy if should_link_policy?
        return unless security_policy.type_approval_policy?

        sync_project_approval_policy_rules_service.sync_policy_diff(policy_diff)
      end

      def should_unlink_policy?
        policy_disabled? || policy_unscoped?
      end

      def should_link_policy?
        policy_enabled? || policy_scoped?
      end

      def policy_enabled?
        policy_diff.status_changed? && security_policy.enabled?
      end

      def policy_disabled?
        policy_diff.status_changed? && !security_policy.enabled?
      end

      def policy_scoped?
        policy_diff.scope_changed? && security_policy.scope_applicable?(project)
      end

      def policy_unscoped?
        policy_diff.scope_changed? && !security_policy.scope_applicable?(project)
      end
    end
  end
end
