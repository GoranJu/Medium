# frozen_string_literal: true

class QueueBackfillSecurityOrchestrationPolicyRuleSchedulesProjectId < Gitlab::Database::Migration[2.2]
  milestone '17.4'
  restrict_gitlab_migration gitlab_schema: :gitlab_main_cell

  MIGRATION = "BackfillSecurityOrchestrationPolicyRuleSchedulesProjectId"
  DELAY_INTERVAL = 2.minutes
  BATCH_SIZE = 1000
  SUB_BATCH_SIZE = 100

  def up
    queue_batched_background_migration(
      MIGRATION,
      :security_orchestration_policy_rule_schedules,
      :id,
      :project_id,
      :security_orchestration_policy_configurations,
      :project_id,
      :security_orchestration_policy_configuration_id,
      job_interval: DELAY_INTERVAL,
      batch_size: BATCH_SIZE,
      sub_batch_size: SUB_BATCH_SIZE
    )
  end

  def down
    delete_batched_background_migration(
      MIGRATION,
      :security_orchestration_policy_rule_schedules,
      :id,
      [
        :project_id,
        :security_orchestration_policy_configurations,
        :project_id,
        :security_orchestration_policy_configuration_id
      ]
    )
  end
end
