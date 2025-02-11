# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncScanResultPoliciesService
      PROJECTS_BATCH_SIZE = 1000

      def initialize(configuration)
        @configuration = configuration
        @sync_project_service = SyncScanResultPoliciesProjectService.new(configuration)
      end

      def execute
        measure(:gitlab_security_policies_update_configuration_duration_seconds) do
          delay = 0
          configuration.all_project_ids.each_slice(PROJECTS_BATCH_SIZE) do |project_ids|
            project_ids.each do |project_id|
              @sync_project_service.execute(project_id, { delay: delay })
            end

            delay += 10.seconds
          end
        end
      end

      private

      attr_reader :configuration

      delegate :measure, to: ::Security::SecurityOrchestrationPolicies::ObserveHistogramsService
    end
  end
end
