# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class SyncPreexistingStatesApprovalRulesService
      include VulnerabilityStatesHelper

      def initialize(merge_request)
        @merge_request = merge_request
        @approval_rules = merge_request.approval_rules.scan_finding.including_scan_result_policy_read
      end

      def execute
        return if merge_request.merged?

        rules_with_preexisting_states = approval_rules.reject do |rule|
          include_newly_detected?(rule)
        end

        return unless rules_with_preexisting_states.any?

        evaluate_rules(rules_with_preexisting_states)
        evaluation.save
      end

      private

      attr_reader :merge_request, :approval_rules

      delegate :project, to: :merge_request, private: true

      def evaluate_rules(approval_rules)
        approval_rules.each do |rule|
          rule_violated, violation_data = preexisting_findings_count_violated?(rule)

          if rule_violated
            log_violated_rule(approval_rule_id: rule.id, approval_rule_name: rule.name)
            evaluation.fail!(rule, data: violation_data)
          else
            evaluation.pass!(rule)
          end
        end
      end

      def preexisting_findings_count_violated?(approval_rule)
        vulnerabilities = vulnerabilities(approval_rule)

        violated = vulnerabilities.count > approval_rule.vulnerabilities_allowed
        [violated, build_violation_data(vulnerabilities)]
      end

      def vulnerabilities(approval_rule)
        finder_params = {
          limit: approval_rule.vulnerabilities_allowed + 1,
          state: states_without_newly_detected(approval_rule.vulnerability_states),
          severity: approval_rule.severity_levels,
          report_type: approval_rule.scanners,
          fix_available: approval_rule.vulnerability_attribute_fix_available,
          false_positive: approval_rule.vulnerability_attribute_false_positive,
          vulnerability_age: approval_rule.scan_result_policy_read&.vulnerability_age
        }
        ::Security::ScanResultPolicies::VulnerabilitiesFinder.new(project, finder_params).execute
      end

      def log_violated_rule(**attributes)
        default_attributes = {
          reason: 'pre_existing scan_finding_rule violated',
          event: 'update_approvals',
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          project_path: merge_request.project.full_path
        }
        Gitlab::AppJsonLogger.info(
          message: 'Updating MR approval rule with pre_existing states',
          **default_attributes.merge(attributes)
        )
      end

      def evaluation
        @evaluation ||= Security::SecurityOrchestrationPolicies::PolicyRuleEvaluationService
          .new(merge_request, approval_rules, :scan_finding)
      end

      def build_violation_data(vulnerabilities)
        return if vulnerabilities.blank?

        violated_uuids = vulnerabilities.with_findings
                                        .limit(Security::ScanResultPolicyViolation::MAX_VIOLATIONS)
                                        .map(&:finding_uuid)
        { uuids: { previously_existing: violated_uuids } }
      end
    end
  end
end
