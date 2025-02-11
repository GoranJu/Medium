# frozen_string_literal: true

class AddProtectedBranchMergeAccessLevelsProtectedBranchNamespaceIdTrigger < Gitlab::Database::Migration[2.2]
  milestone '17.7'

  def up
    install_sharding_key_assignment_trigger(
      table: :protected_branch_merge_access_levels,
      sharding_key: :protected_branch_namespace_id,
      parent_table: :protected_branches,
      parent_sharding_key: :namespace_id,
      foreign_key: :protected_branch_id
    )
  end

  def down
    remove_sharding_key_assignment_trigger(
      table: :protected_branch_merge_access_levels,
      sharding_key: :protected_branch_namespace_id,
      parent_table: :protected_branches,
      parent_sharding_key: :namespace_id,
      foreign_key: :protected_branch_id
    )
  end
end
