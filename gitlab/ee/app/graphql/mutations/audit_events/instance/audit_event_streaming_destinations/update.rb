# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Instance
      module AuditEventStreamingDestinations
        class Update < Base
          graphql_name 'InstanceAuditEventStreamingDestinationsUpdate'

          include ::AuditEvents::Changes
          include ::AuditEvents::StreamDestinationSyncHelper

          UPDATE_EVENT_NAME = 'updated_instance_audit_event_streaming_destination'
          AUDIT_EVENT_COLUMNS = [:config, :name, :category, :secret_token].freeze

          argument :id, ::Types::GlobalIDType[::AuditEvents::Instance::ExternalStreamingDestination],
            required: true,
            description: 'ID of external audit event destination to update.'

          argument :config, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- Different type of destinations will have different configs
            required: false,
            description: 'Destination config.'

          argument :name, GraphQL::Types::String,
            required: false,
            description: 'Destination name.'

          argument :category, GraphQL::Types::String,
            required: false,
            description: 'Destination category.'

          argument :secret_token, GraphQL::Types::String,
            required: false,
            description: 'Secret token.'

          field :external_audit_event_destination, ::Types::AuditEvents::Instance::StreamingDestinationType,
            null: true,
            description: 'Updated destination.'

          def resolve(id:, config: nil, name: nil, category: nil, secret_token: nil)
            destination = authorized_find!(id: id)

            destination_attributes = {
              config: config,
              name: name,
              category: category,
              secret_token: secret_token
            }.compact

            if destination.update(destination_attributes)
              audit_update(destination)
              update_legacy_destination(destination)

              {
                external_audit_event_destination: destination,
                errors: []
              }
            else
              { external_audit_event_destination: nil, errors: Array(destination.errors) }
            end
          end

          private

          def audit_update(destination)
            AUDIT_EVENT_COLUMNS.each do |column|
              audit_changes(
                column,
                as: column.to_s,
                entity: Gitlab::Audit::InstanceScope.new,
                model: destination,
                event_type: UPDATE_EVENT_NAME
              )
            end
          end
        end
      end
    end
  end
end
