# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class UpdateViolationsService
      attr_reader :merge_request, :violated_policies, :unviolated_policies, :violation_data, :report_type

      delegate :project, to: :merge_request

      def initialize(merge_request, report_type)
        @merge_request = merge_request
        @violated_policies = Set.new
        @unviolated_policies = Set.new
        @violation_data = {}
        @report_type = report_type
      end

      def add(violated, unviolated)
        violated_policies.merge(violated.compact)
        unviolated_policies.merge(unviolated.compact)
      end

      def add_violation(policy, data, context: nil)
        add([policy], [])

        @violation_data[policy.id] ||= {}
        @violation_data[policy.id].deep_merge!({ context: context, violations: { report_type => data } }.compact_blank)
      end

      def remove_violation(policy)
        unviolated_policies.add(policy)
      end

      def add_error(policy, error, context: nil, **extra_data)
        add([policy], [])

        violation_data[policy.id] ||= {}
        violation_data[policy.id][:errors] ||= []
        violation_data[policy.id][:errors] << {
          error: Security::ScanResultPolicyViolation::ERRORS[error],
          **extra_data
        }
        violation_data[policy.id].deep_merge!({ context: context }) if context.present?
      end

      def execute
        Security::ScanResultPolicyViolation.transaction do
          delete_violations if unviolated_policies.any?
          create_violations if violated_policies.any?
        end

        publish_violations_updated_event if unviolated_policies.any? || violated_policies.any?

        [violated_policies.clear, unviolated_policies.clear]
      end

      # rubocop: disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- unviolated_policies is a Set
      def delete_violations
        Security::ScanResultPolicyViolation
          .where(merge_request_id: merge_request.id, scan_result_policy_id: unviolated_policies.pluck(:id))
          .each_batch(order_hint: :updated_at) { |batch| batch.delete_all }
      end
      # rubocop: enable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit

      def create_violations
        attrs = violated_policies.map do |policy|
          {
            scan_result_policy_id: policy.id,
            approval_policy_rule_id: policy.approval_policy_rule&.id,
            merge_request_id: merge_request.id,
            project_id: merge_request.project_id,
            violation_data: violation_data[policy.id],
            status: ScanResultPolicyViolation.statuses[violation_status(policy)]
          }
        end
        return unless attrs.any?

        Security::ScanResultPolicyViolation.upsert_all(attrs, unique_by: %w[scan_result_policy_id merge_request_id])
      end

      # We only warn for errored fail-open policies, in other cases (when we have actual `violations`), we should fail.
      def violation_status(policy)
        policy.fail_open? && !violation_data[policy.id]&.key?(:violations) ? :warn : :failed
      end

      def publish_violations_updated_event
        return unless ::Feature.enabled?(:policy_mergability_check, merge_request.project)

        ::Gitlab::EventStore.publish(
          ::MergeRequests::ViolationsUpdatedEvent.new(
            data: { merge_request_id: merge_request.id }
          )
        )
      end
    end
  end
end
