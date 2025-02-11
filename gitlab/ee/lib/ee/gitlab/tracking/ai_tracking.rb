# frozen_string_literal: true

module EE
  module Gitlab
    module Tracking
      module AiTracking
        extend ::Gitlab::Utils::Override

        POSSIBLE_MODELS = [Ai::CodeSuggestionEvent, Ai::DuoChatEvent].freeze

        override :track_event
        def track_event(event_name, **context_hash)
          event = build_event_model(event_name, context_hash)

          return unless event

          store_to_clickhouse(event)
          store_to_postgres(event)

          Ai::UserMetrics.refresh_last_activity_on(context_hash[:user])
        end

        private

        def build_event_model(event_name, context_hash = {})
          matched_model = POSSIBLE_MODELS.detect { |model| model.related_event?(event_name) }
          return unless matched_model

          context_hash = context_hash.with_indifferent_access
          context_hash[:event] = event_name
          context_hash[:namespace_path] ||= build_traversal_path(context_hash)

          basic_attributes = context_hash.slice(*matched_model::PERMITTED_ATTRIBUTES)
          payload_attributes = context_hash.slice(*matched_model::PAYLOAD_ATTRIBUTES)

          matched_model.new(basic_attributes.merge(payload: payload_attributes))
        end

        def store_to_clickhouse(event)
          return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

          event.store_to_clickhouse
        end

        def store_to_postgres(event)
          return unless event.respond_to?(:store_to_pg)

          event.store_to_pg
        end

        def build_traversal_path(context_hash)
          context_hash[:project]&.project_namespace&.traversal_path ||
            context_hash[:namespace]&.traversal_path
        end
      end
    end
  end
end
