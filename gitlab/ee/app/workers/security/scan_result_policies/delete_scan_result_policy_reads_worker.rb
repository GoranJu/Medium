# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class DeleteScanResultPolicyReadsWorker
      include ApplicationWorker

      feature_category :security_policy_management
      data_consistency :sticky
      deduplicate :until_executed
      idempotent!

      def perform(configuration_id)
        Security::OrchestrationPolicyConfiguration.find_by_id(configuration_id)&.delete_scan_result_policy_reads
      end
    end
  end
end
