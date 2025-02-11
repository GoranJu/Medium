# frozen_string_literal: true

module CloudConnector
  class Access < ApplicationRecord
    # Technically, access data has no expiration date, but we know that tokens
    # are good for at most 3 days currently, so this is a good estimate.
    STALE_PERIOD = 3.days

    self.table_name = 'cloud_connector_access'
    validates :data, json_schema: { filename: "cloud_connector_access" }
    validates :data, presence: true
  end
end
