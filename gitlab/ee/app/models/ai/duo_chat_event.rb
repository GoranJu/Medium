# frozen_string_literal: true

module Ai
  class DuoChatEvent < ApplicationRecord
    include PartitionedTable
    include UsageEvent

    self.table_name = "ai_duo_chat_events"
    self.clickhouse_table_name = "duo_chat_events"
    self.primary_key = :id

    partitioned_by :timestamp, strategy: :monthly, retain_for: 3.months

    PAYLOAD_ATTRIBUTES = [].freeze

    attribute :timestamp, :datetime, default: -> { DateTime.current }

    enum event: { request_duo_chat_response: 1 }

    belongs_to :user

    validates :user_id, :timestamp, :personal_namespace_id, presence: true
    validates :payload, json_schema: { filename: "duo_chat_event" }, allow_blank: true
    validate :validate_recent_timestamp, on: :create

    before_validation :populate_sharding_key

    def store_to_pg
      return false unless valid?

      Ai::UsageEventWriteBuffer.add(self.class.name, attributes.compact)
    end

    private

    def populate_sharding_key
      self.personal_namespace_id = user.namespace_id if user
    end

    def validate_recent_timestamp
      return unless timestamp && timestamp < self.class.partitioning_strategy.retain_for.ago

      errors.add(:timestamp, _('must be 3 months old at the most'))
    end
  end
end
