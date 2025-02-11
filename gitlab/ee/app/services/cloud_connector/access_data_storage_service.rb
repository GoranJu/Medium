# frozen_string_literal: true

# AccessDataStorageService creates or updates the CloudConnector::Access record with the data we received
# from the CustomersDot application. By design, the DB table has one or zero rows.
module CloudConnector
  class AccessDataStorageService
    def initialize(data)
      @data = data
    end

    def execute
      record = CloudConnector::Access.last || CloudConnector::Access.new

      if record.update(data: data, updated_at: Time.current)
        ServiceResponse.success
      else
        error_message = record.errors.full_messages.join(", ")
        Gitlab::AppLogger.error("Cloud Connector Access data update failed: #{error_message}")

        ServiceResponse.error(message: error_message)
      end
    end

    private

    attr_reader :data
  end
end
