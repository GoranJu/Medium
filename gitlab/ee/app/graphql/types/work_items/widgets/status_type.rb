# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      # rubocop:disable Graphql/AuthorizeTypes
      class StatusType < BaseObject
        graphql_name 'WorkItemWidgetStatus'
        description 'Represents a status widget'

        implements ::Types::WorkItems::WidgetInterface

        # Only represents requirements status right now
        field :status, GraphQL::Types::String,
          null: true,
          experiment: { milestone: '15.5' },
          description: 'Status of the work item.'
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
