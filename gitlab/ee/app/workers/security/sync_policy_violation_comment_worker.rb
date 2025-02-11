# frozen_string_literal: true

module Security
  class SyncPolicyViolationCommentWorker
    include ApplicationWorker
    include ::Security::ScanResultPolicies::PolicyViolationCommentGenerator

    idempotent!
    data_consistency :sticky
    feature_category :security_policy_management

    def perform(merge_request_id)
      merge_request = MergeRequest.find_by_id(merge_request_id)

      unless merge_request
        logger.info(structured_payload(message: 'Merge request not found.', merge_request_id: merge_request_id))
        return
      end

      return unless merge_request.project.licensed_feature_available?(:security_orchestration_policies)

      approval_rules = merge_request.approval_rules
      generate_comment(merge_request, approval_rules.scan_finding, :scan_finding)
      generate_comment(merge_request, approval_rules.license_scanning, :license_scanning)
    end

    private

    def generate_comment(merge_request, rules, report_type)
      return if rules.blank?

      generate_policy_bot_comment(merge_request, rules.applicable_to_branch(merge_request.target_branch), report_type)
    end
  end
end
