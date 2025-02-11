# frozen_string_literal: true

module Ai
  module Conversation
    class Message < ApplicationRecord
      self.table_name = :ai_conversation_messages

      belongs_to :organization, class_name: 'Organizations::Organization'
      belongs_to :thread, class_name: 'Ai::Conversation::Thread', inverse_of: :messages

      validates :content, :role, :thread_id, presence: true

      scope :for_thread, ->(thread) { where(thread: thread) }
      # This message_xid is a secure random ID that is generated in runtime.
      # https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/gitlab/llm/ai_message.rb#L47
      scope :for_message_xid, ->(message_xid) { where(message_xid: message_xid) }
      scope :ordered, -> { order(id: :asc) }

      enum role: { user: 1, assistant: 2 }

      before_create :populate_organization

      def self.recent(limit)
        order(id: :desc).limit(limit).reverse
      end

      private

      def populate_organization
        self.organization ||= thread.organization
      end
    end
  end
end
