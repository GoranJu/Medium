# frozen_string_literal: true

class AddFkFromPCiBuildTagsToPCiBuilds < Gitlab::Database::Migration[2.2]
  include Gitlab::Database::PartitioningMigrationHelpers

  milestone '17.3'

  disable_ddl_transaction!

  SOURCE_TABLE_NAME = :p_ci_build_tags
  TARGET_TABLE_NAME = :p_ci_builds
  FK_NAME = :fk_rails_d7bd025909
  COLUMN = [:partition_id, :build_id]
  TARGET_COLUMN = [:partition_id, :id]

  def up
    add_concurrent_partitioned_foreign_key(
      SOURCE_TABLE_NAME, TARGET_TABLE_NAME,
      column: COLUMN,
      target_column: TARGET_COLUMN,
      validate: true,
      on_update: :cascade,
      on_delete: :cascade,
      reverse_lock_order: true,
      name: FK_NAME
    )
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists(
        SOURCE_TABLE_NAME,
        TARGET_TABLE_NAME,
        name: FK_NAME,
        reverse_lock_order: true
      )
    end
  end
end
