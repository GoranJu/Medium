# frozen_string_literal: true

module Types
  module ComplianceManagement
    class ComplianceRequirementInputType < BaseInputObject
      graphql_name 'ComplianceRequirementInput'

      argument :name,
        GraphQL::Types::String,
        required: false,
        description: 'New name for the compliance requirement.'

      argument :description,
        GraphQL::Types::String,
        required: false,
        description: 'New description for the compliance requirement.'

      argument :control_expression,
        GraphQL::Types::String,
        required: false,
        description: 'Control expression for the compliance requirement.'
    end
  end
end
