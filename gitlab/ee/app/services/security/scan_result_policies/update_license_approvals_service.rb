# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class UpdateLicenseApprovalsService
      include Gitlab::Utils::StrongMemoize

      def initialize(merge_request, pipeline, preexisting_states = false)
        @merge_request = merge_request
        @pipeline = pipeline
        @preexisting_states = preexisting_states
        @approval_rules = merge_request
                            .approval_rules
                            .report_approver
                            .license_scanning
                            .with_scan_result_policy_read
                            .including_scan_result_policy_read
      end

      def execute
        return if merge_request.merged?
        return if approval_rules.empty?
        return if !preexisting_states && !scanner.results_available?

        filtered_rules = filter_approval_rules(approval_rules)
        return if filtered_rules.empty?

        evaluate_rules(filtered_rules)
        evaluation.save
      end

      private

      attr_reader :merge_request, :pipeline, :preexisting_states, :approval_rules

      delegate :project, to: :merge_request

      def filter_approval_rules(approval_rules)
        rule_filter = ->(approval_rule) { approval_rule.scan_result_policy_read.newly_detected? }

        preexisting_states ? approval_rules.reject(&rule_filter) : approval_rules.select(&rule_filter)
      end

      def evaluate_rules(license_approval_rules)
        license_approval_rules.each do |approval_rule|
          # We only error for fail-open. Fail closed policy is evaluated as "failing"
          if !target_branch_pipeline && fail_open?(approval_rule)
            evaluation.error!(approval_rule, :target_pipeline_missing, context: validation_context)
            next
          end

          rule_violated, violation_data = rule_violated?(approval_rule)

          if rule_violated
            evaluation.fail!(approval_rule, data: violation_data, context: validation_context)
            log_update_approval_rule(approval_rule_id: approval_rule.id, approval_rule_name: approval_rule.name)
          else
            evaluation.pass!(approval_rule)
          end
        end
      end

      def rule_violated?(rule)
        denied_licenses_with_dependencies = violation_checker.execute(rule.scan_result_policy_read)

        if denied_licenses_with_dependencies.present?
          return true, build_violation_data(denied_licenses_with_dependencies)
        end

        [false, nil]
      end

      def violation_checker
        report = scanner.report
        target_branch_report = ::Gitlab::LicenseScanning.scanner_for_pipeline(project, target_branch_pipeline).report

        Security::ScanResultPolicies::LicenseViolationChecker.new(
          project, report, target_branch_report
        )
      end

      def scanner
        ::Gitlab::LicenseScanning.scanner_for_pipeline(project, pipeline)
      end
      strong_memoize_attr :scanner

      def evaluation
        @evaluation ||= Security::SecurityOrchestrationPolicies::PolicyRuleEvaluationService
          .new(merge_request, approval_rules, :license_scanning)
      end

      def target_branch_pipeline
        target_pipeline = merge_request.latest_comparison_pipeline_with_sbom_reports

        return target_pipeline if target_pipeline.present?

        related_target_pipeline
      end
      strong_memoize_attr :target_branch_pipeline

      def related_target_pipeline
        target_pipeline_without_report = merge_request.merge_base_pipeline || merge_request.base_pipeline

        return unless target_pipeline_without_report

        related_pipeline_ids = Security::RelatedPipelinesFinder.new(target_pipeline_without_report, {
          sources: Enums::Ci::Pipeline.ci_and_security_orchestration_sources.values,
          ref: merge_request.target_branch
        }).execute

        pipelines = project.all_pipelines.id_in(related_pipeline_ids)

        merge_request.find_pipeline_with_dependency_scanning_reports(pipelines)
      end

      def validation_context
        { pipeline_ids: [pipeline&.id].compact, target_pipeline_ids: [target_branch_pipeline&.id].compact }
      end

      def log_update_approval_rule(**attributes)
        default_attributes = {
          reason: 'license_finding rule violated',
          event: 'update_approvals',
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          project_path: project.full_path
        }

        Gitlab::AppJsonLogger.info(
          message: 'Updating MR approval rule',
          **default_attributes.merge(attributes).merge(validation_context)
        )
      end

      def build_violation_data(denied_licenses_with_dependencies)
        return if denied_licenses_with_dependencies.blank?

        denied_licenses_with_dependencies.first(Security::ScanResultPolicyViolation::MAX_VIOLATIONS)
                                         .to_h
                                         .transform_values do |dependencies|
          Security::ScanResultPolicyViolation.trim_violations(dependencies)
        end
      end

      def fail_open?(approval_rule)
        approval_rule.scan_result_policy_read&.fail_open?
      end
    end
  end
end
