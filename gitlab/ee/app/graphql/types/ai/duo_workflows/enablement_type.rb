# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      class EnablementType < Types::BaseObject # rubocop:disable Graphql/AuthorizeTypes -- parent is already authorized
        graphql_name 'DuoWorkflowEnablement'
        description 'Duo Workflow enablement status checks.'

        field :enabled, GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether GitLab Duo Workflow is enabled for current user and the project.'

        field :checks, [::Types::Ai::DuoWorkflows::EnablementCheckType],
          null: true,
          description: 'Enablement checks.'
      end
    end
  end
end
