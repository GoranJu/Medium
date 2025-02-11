# frozen_string_literal: true

# rubocop: disable Graphql/AuthorizeTypes -- because ComplianceRequirementType is, and should only be, accessible via ComplianceFrameworkType

module Types
  module ComplianceManagement
    class ComplianceRequirementType < Types::BaseObject
      graphql_name 'ComplianceRequirement'
      description 'Represents a ComplianceRequirement associated with a ComplianceFramework'

      field :id, GraphQL::Types::ID,
        null: false,
        description: 'Compliance requirement ID.'

      field :name, GraphQL::Types::String,
        null: false,
        description: 'Name of the compliance requirement.'

      field :description, GraphQL::Types::String,
        null: false,
        description: 'Description of the compliance requirement.'

      field :control_expression, GraphQL::Types::String,
        null: true,
        description: 'Control expression of the compliance requirement.'

      field :requirement_type, GraphQL::Types::String,
        null: false,
        description: 'Type of the compliance requirement.'

      field :compliance_requirements_controls,
        ::Types::ComplianceManagement::ComplianceRequirementsControlType.connection_type,
        null: true,
        description: 'Compliance controls of the compliance requirement.'
    end
  end
end

# rubocop: enable Graphql/AuthorizeTypes
