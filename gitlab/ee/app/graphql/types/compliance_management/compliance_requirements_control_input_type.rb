# frozen_string_literal: true

module Types
  module ComplianceManagement
    class ComplianceRequirementsControlInputType < BaseInputObject
      graphql_name 'ComplianceRequirementsControlInput'

      argument :name,
        GraphQL::Types::String,
        required: false,
        description: 'New name for the compliance requirement control.'

      argument :expression,
        GraphQL::Types::String,
        required: false,
        description: 'Expression of the compliance control.'
    end
  end
end
