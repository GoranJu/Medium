# frozen_string_literal: true

class FinalizeBackfillProjectIdToSecurityScans < Gitlab::Database::Migration[2.2]
  milestone '17.6'
  disable_ddl_transaction!

  restrict_gitlab_migration gitlab_schema: :gitlab_sec

  def up
    ensure_batched_background_migration_is_finished(
      job_class_name: 'BackfillProjectIdToSecurityScans',
      table_name: :security_scans,
      column_name: :id,
      job_arguments: [],
      finalize: true
    )
  end

  def down; end
end
