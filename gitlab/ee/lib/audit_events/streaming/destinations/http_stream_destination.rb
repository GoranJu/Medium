# frozen_string_literal: true

module AuditEvents
  module Streaming
    module Destinations
      class HttpStreamDestination < BaseStreamDestination
        def stream
          Gitlab::HTTP.post(
            destination.config["url"],
            body: request_body,
            headers: build_headers
          )
        rescue URI::InvalidURIError, *Gitlab::HTTP::HTTP_ERRORS => e
          Gitlab::ErrorTracking.log_exception(e)
        end

        private

        def build_headers
          headers = @destination.config["headers"] || {}
          headers[EVENT_TYPE_HEADER_KEY] = @event_type if @event_type.present?
          headers
        end
      end
    end
  end
end
