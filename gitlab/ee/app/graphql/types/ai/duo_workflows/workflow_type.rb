# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      class WorkflowType < Types::BaseObject
        graphql_name 'DuoWorkflow'
        description 'A Duo Workflow'
        present_using ::Ai::DuoWorkflows::WorkflowPresenter
        authorize :read_duo_workflow

        def self.authorization_scopes
          [:api, :read_api, :ai_features]
        end

        field :id, type: GraphQL::Types::ID,
          null: false, description: 'ID of the workflow.'

        # The user id will always be the current_user.id as
        # only workflow owners can read a workflow
        field :user_id, Types::GlobalIDType[User],
          null: false, description: 'ID of the user.'

        field :project_id, Types::GlobalIDType[Project],
          null: false, description: 'ID of the project.'

        field :human_status, GraphQL::Types::String,
          null: false, description: 'Human-readable status of the workflow.'

        field :created_at, Types::TimeType,
          null: false, description: 'Timestamp of when the workflow was created.'

        field :updated_at, Types::TimeType,
          null: false, description: 'Timestamp of when the workflow was last updated.'

        field :goal, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features],
          description: 'Goal of the workflow.'

        field :workflow_definition, GraphQL::Types::String,
          description: 'Duo Workflow type based on its capabilities.'
      end
    end
  end
end
