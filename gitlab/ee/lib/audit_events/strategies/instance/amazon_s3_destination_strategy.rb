# frozen_string_literal: true

module AuditEvents
  module Strategies
    module Instance
      class AmazonS3DestinationStrategy < BaseAmazonS3DestinationStrategy
        def streamable?
          ::License.feature_available?(:external_audit_events) &&
            AuditEvents::Instance::AmazonS3Configuration.exists?
        end

        private

        def destinations
          # Only 5 Amazon S3 configs are allowed per instance
          AuditEvents::Instance::AmazonS3Configuration.all
        end
      end
    end
  end
end
