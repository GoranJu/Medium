# frozen_string_literal: true

class PrepareAsyncIndexOnIssuesCorrectTypeProjectCreatedAtState < Gitlab::Database::Migration[2.2]
  milestone '17.6'
  disable_ddl_transaction!

  INDEX_NAME = 'tmp_idx_issues_on_correct_type_project_created_at_state'

  def up
    # Temporary index to be removed with https://gitlab.com/gitlab-org/gitlab/-/issues/500165
    # TODO: Index to be created synchronously in https://gitlab.com/gitlab-org/gitlab/-/merge_requests/170005
    # rubocop:disable Migration/PreventIndexCreation -- Legacy migration
    prepare_async_index :issues, # -- Tmp index needed to fix work item type ids
      # rubocop:enable Migration/PreventIndexCreation
      [:correct_work_item_type_id, :project_id, :created_at, :state_id],
      name: INDEX_NAME
  end

  def down
    unprepare_async_index_by_name :issues, INDEX_NAME
  end
end
