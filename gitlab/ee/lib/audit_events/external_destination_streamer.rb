# frozen_string_literal: true

module AuditEvents
  class ExternalDestinationStreamer
    attr_reader :event_name, :audit_event

    STRATEGIES = [
      AuditEvents::Strategies::GroupExternalDestinationStrategy,
      AuditEvents::Strategies::InstanceExternalDestinationStrategy,
      AuditEvents::Strategies::GoogleCloudLoggingDestinationStrategy,
      AuditEvents::Strategies::Instance::GoogleCloudLoggingDestinationStrategy,
      AuditEvents::Strategies::AmazonS3DestinationStrategy,
      AuditEvents::Strategies::Instance::AmazonS3DestinationStrategy
    ].freeze

    def initialize(event_name, audit_event)
      @event_name = event_name
      @audit_event = audit_event
    end

    def stream_to_destinations
      streamable_strategies.each(&:execute)
      return unless feature_flag_enabled?

      streamers.each(&:execute)
    end

    def streamable?
      return !streamable_strategies.empty? unless feature_flag_enabled?

      !streamable_strategies.empty? || streamers.any?(&:streamable?)
    end

    private

    def streamers
      @streamers ||= [
        AuditEvents::Streaming::Group::Streamer.new(event_name, audit_event),
        AuditEvents::Streaming::Instance::Streamer.new(event_name, audit_event)
      ]
    end

    def streamable_strategies
      @streamable_strategies ||= STRATEGIES.filter_map do |strategy|
        strategy_instance = strategy.new(event_name, audit_event)
        strategy_instance if strategy_instance.streamable?
      end
    end

    def feature_flag_enabled?
      Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor, :instance)
    end
  end
end
