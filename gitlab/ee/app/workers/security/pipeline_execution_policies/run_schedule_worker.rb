# frozen_string_literal: true

module Security
  module PipelineExecutionPolicies
    class RunScheduleWorker
      include ApplicationWorker

      idempotent!

      data_consistency :sticky
      feature_category :security_policy_management

      PIPELINE_SOURCE = :pipeline_execution_policy_schedule
      EVENT_KEY = 'scheduled_pipeline_execution_policy_failure'

      def perform(schedule_id)
        schedule = Security::PipelineExecutionProjectSchedule.find_by_id(schedule_id) || return

        return if Feature.disabled?(:scheduled_pipeline_execution_policies, schedule.project)

        result = execute(schedule)

        log_pipeline_creation_failure(result, schedule) if result.error?
      end

      private

      def execute(schedule)
        ci_content = schedule.ci_content.deep_stringify_keys.to_yaml

        Ci::CreatePipelineService.new(
          schedule.project,
          schedule.project.security_policy_bot,
          ref: schedule.project.default_branch_or_main
        ).execute(PIPELINE_SOURCE, content: ci_content, ignore_skip_ci: true)
      end

      def log_pipeline_creation_failure(result, schedule)
        Gitlab::AppJsonLogger.error(
          build_structured_payload(
            event: EVENT_KEY,
            message: result.message,
            reason: result.reason,
            project_id: schedule.project_id,
            schedule_id: schedule.id,
            policy_id: schedule.security_policy.id))
      end
    end
  end
end
