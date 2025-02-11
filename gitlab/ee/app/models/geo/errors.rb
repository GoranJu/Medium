# frozen_string_literal: true

module Geo
  module Errors
    BaseError = Class.new(StandardError)
    class StatusTimeoutError < BaseError
      def message
        "Job running too long, approaching deduplication TTL"
      end
    end
  end
end
