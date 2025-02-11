# frozen_string_literal: true

module AuditEvents
  module CommonAuditEventStreamable
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    def stream_to_external_destinations(use_json: false, event_name: 'audit_operation')
      return unless can_stream_to_external_destination?(event_name)

      perform_params = use_json ? [event_name, nil, streaming_json] : [event_name, id, nil]
      ::AuditEvents::AuditEventStreamingWorker.perform_async(*perform_params)
    end

    def entity_is_group_or_project?
      %w[Group Project].include?(entity_type)
    end

    private

    def can_stream_to_external_destination?(event_name)
      return false if entity.nil?

      return false unless Feature.enabled?(:stream_audit_events_from_new_tables,
        entity.instance_of?(::Gitlab::Audit::InstanceScope) ? :instance : entity)

      ::AuditEvents::ExternalDestinationStreamer.new(event_name, self).streamable?
    end

    def streaming_json
      ::Gitlab::Json.generate(self, methods: [:root_group_entity_id])
    end
  end
end
