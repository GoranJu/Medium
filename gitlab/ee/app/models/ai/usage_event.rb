# frozen_string_literal: true

module Ai
  module UsageEvent
    extend ActiveSupport::Concern
    include ClickHouseModel

    included do
      class << self
        def related_event?(event_name)
          events.key?(event_name)
        end
      end
    end

    PERMITTED_ATTRIBUTES = %w[user user_id organization organization_id personal_namespace_id namespace_path timestamp
      event].freeze

    def to_clickhouse_csv_row
      {
        event: self.class.events[event],
        timestamp: timestamp.to_f,
        user_id: user&.id
      }
    end

    # Default to empty hash if payload is empty
    def payload
      super || {}
    end
  end
end
