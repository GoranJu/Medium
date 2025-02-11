# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      # rubocop:disable Graphql/AuthorizeTypes -- already authorized in parent type
      class CustomFieldsType < BaseObject
        graphql_name 'WorkItemWidgetCustomFields'
        description 'Represents a custom fields widget'

        implements Types::WorkItems::WidgetInterface

        field :custom_field_values, [Types::WorkItems::CustomFieldValueInterface], null: true,
          description: 'Custom field values associated to the work item.',
          experiment: { milestone: '17.9' }
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
