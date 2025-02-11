# frozen_string_literal: true

module Ai
  class CodeSuggestionEvent < ApplicationRecord
    include PartitionedTable
    include UsageEvent

    self.table_name = "ai_code_suggestion_events"
    self.clickhouse_table_name = "code_suggestion_usages"
    self.primary_key = :id

    partitioned_by :timestamp, strategy: :monthly, retain_for: 3.months

    PAYLOAD_ATTRIBUTES = %w[language suggestion_size unique_tracking_id branch_name].freeze

    attribute :timestamp, :datetime, default: -> { DateTime.current }

    enum event: {
      code_suggestions_requested: 1, # old data https://gitlab.com/gitlab-org/gitlab/-/issues/462809
      code_suggestion_shown_in_ide: 2,
      code_suggestion_accepted_in_ide: 3,
      code_suggestion_rejected_in_ide: 4,
      code_suggestion_direct_access_token_refresh: 5 # old data https://gitlab.com/gitlab-org/gitlab/-/issues/462809
    }

    belongs_to :user
    belongs_to :organization, class_name: 'Organizations::Organization'

    validates :user_id, :timestamp, :organization_id, presence: true
    validates :payload, json_schema: { filename: "code_suggestion_event" }, allow_blank: true
    validate :validate_recent_timestamp, on: :create

    before_validation :populate_organization_id

    def to_clickhouse_csv_row
      super.merge({
        unique_tracking_id: payload['unique_tracking_id'],
        suggestion_size: payload['suggestion_size'],
        language: payload['language'],
        branch_name: payload['branch_name']
      })
    end

    def store_to_pg
      return false unless valid?

      Ai::UsageEventWriteBuffer.add(self.class.name, attributes.compact)
    end

    private

    def populate_organization_id
      self.organization_id = user.namespace&.organization_id if user
    end

    def validate_recent_timestamp
      return unless timestamp && timestamp < self.class.partitioning_strategy.retain_for.ago

      errors.add(:timestamp, _('must be 3 months old at the most'))
    end
  end
end
