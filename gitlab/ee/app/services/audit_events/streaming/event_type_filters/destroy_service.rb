# frozen_string_literal: true

module AuditEvents
  module Streaming
    module EventTypeFilters
      class DestroyService < BaseService
        def execute
          errors = validate!

          if errors.blank?
            destination.event_type_filters.audit_event_type_in(event_type_filters).delete_all
            log_audit_event(name: 'event_type_filters_deleted', message: 'Deleted audit event type filter(s)')
            ServiceResponse.success
          else
            ServiceResponse.error(message: errors)
          end
        end

        private

        def validate!
          existing_filters = destination.event_type_filters
                                        .audit_event_type_in(event_type_filters)
                                        .pluck_audit_event_type
          missing_filters = event_type_filters - existing_filters
          [error_message(missing_filters)] if missing_filters.present?
        end

        def error_message(missing_filters)
          format(_("Couldn't find event type filters where audit event type(s): %{missing_filters}"),
            missing_filters: missing_filters.join(', '))
        end
      end
    end
  end
end
