# frozen_string_literal: true

class AddBroadcastMessageForeignKeyToBroadcastMessageDismissals < Gitlab::Database::Migration[2.2]
  milestone '17.1'

  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :user_broadcast_message_dismissals, :broadcast_messages, column: :broadcast_message_id,
      on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :user_broadcast_message_dismissals, column: :broadcast_message_id
    end
  end
end
