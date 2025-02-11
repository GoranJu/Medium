# frozen_string_literal: true

class QueueRequeueBackfillSeatAssignmentsTable < Gitlab::Database::Migration[2.2]
  milestone '17.8'

  restrict_gitlab_migration gitlab_schema: :gitlab_main

  MIGRATION = "BackfillSeatAssignmentsTable"
  DELAY_INTERVAL = 2.minutes
  BATCH_SIZE = 10_000
  SUB_BATCH_SIZE = 1000

  def up
    # no-op, there were invalid records that needs to be fixed.
    # Fixed by: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/177865
  end

  def down
    # no-op, there were invalid records that needs to be fixed.
    # Fixed by: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/177865
  end
end
