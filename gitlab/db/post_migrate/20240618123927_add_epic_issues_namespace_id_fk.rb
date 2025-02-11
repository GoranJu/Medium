# frozen_string_literal: true

class AddEpicIssuesNamespaceIdFk < Gitlab::Database::Migration[2.2]
  milestone '17.3'
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :epic_issues, :namespaces, column: :namespace_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :epic_issues, column: :namespace_id
    end
  end
end
