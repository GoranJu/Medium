# frozen_string_literal: true

# rubocop: disable Graphql/AuthorizeTypes -- because ComplianceRequirementsControlType is, and should only be, accessible via ComplianceRequirementType

module Types
  module ComplianceManagement
    class ComplianceRequirementsControlType < Types::BaseObject
      graphql_name 'ComplianceRequirementsControl'
      description 'Represents a ComplianceRequirementsControl associated with a ComplianceRequirement'

      field :id, GraphQL::Types::ID,
        null: false,
        description: 'Compliance requirements control ID.'

      field :name, GraphQL::Types::String,
        null: false,
        description: 'Name of the compliance control.'

      field :expression, GraphQL::Types::String,
        null: true,
        description: 'Expression of the compliance control.'

      field :control_type, GraphQL::Types::String,
        null: false,
        description: 'Type of the compliance control.'
    end
  end
end

# rubocop: enable Graphql/AuthorizeTypes
