# frozen_string_literal: true

module Security
  module PipelineExecutionPolicies
    class ScheduleWorker
      include ApplicationWorker
      include CronjobQueue
      include Security::SecurityOrchestrationPolicies::CadenceChecker
      include ExclusiveLeaseGuard

      LEASE_KEY = 'security_pipeline_execution_policies_schedule'
      LEASE_TIMEOUT = 5.minutes

      idempotent!

      data_consistency :sticky
      feature_category :security_policy_management

      def perform
        try_obtain_lease do
          scope = Security::PipelineExecutionProjectSchedule
            .runnable_schedules
            .including_security_policy_and_project
            .ordered_by_next_run_at

          iterator = Gitlab::Pagination::Keyset::Iterator.new(scope: scope)

          iterator.each_batch(of: 1000) do |schedules|
            schedules.each do |schedule|
              next unless Feature.enabled?(:scheduled_pipeline_execution_policies, schedule.project)

              unless valid_cadence?(schedule.cron)
                log_invalid_cadence_error(schedule.project_id, schedule.cron)

                next
              end

              with_context(project: schedule.project_id) do
                Security::PipelineExecutionPolicies::RunScheduleWorker.perform_async(schedule.id)
              end

              schedule.schedule_next_run!
            end
          end
        end
      end

      private

      def lease_key
        LEASE_KEY
      end

      def lease_timeout
        LEASE_TIMEOUT
      end
    end
  end
end
