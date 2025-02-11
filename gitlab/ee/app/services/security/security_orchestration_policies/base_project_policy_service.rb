# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class BaseProjectPolicyService
      include Gitlab::Utils::StrongMemoize

      def initialize(project:, security_policy:)
        @project = project
        @security_policy = security_policy
      end

      private

      attr_reader :project, :security_policy

      def sync_project_approval_policy_rules_service
        Security::SecurityOrchestrationPolicies::SyncProjectApprovalPolicyRulesService.new(
          project: project, security_policy: security_policy
        )
      end
      strong_memoize_attr :sync_project_approval_policy_rules_service

      def link_policy
        return unless security_policy.enabled
        return unless security_policy.scope_applicable?(project)

        security_policy.link_project!(project)

        return unless security_policy.type_approval_policy?

        sync_project_approval_policy_rules_service.create_rules
      end

      def unlink_policy
        security_policy.unlink_project!(project)

        return unless security_policy.type_approval_policy?

        sync_project_approval_policy_rules_service.delete_rules
      end
    end
  end
end
