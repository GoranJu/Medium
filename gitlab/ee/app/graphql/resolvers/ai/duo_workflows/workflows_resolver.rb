# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoWorkflows
      class WorkflowsResolver < BaseResolver
        type Types::Ai::DuoWorkflows::WorkflowType, null: false

        argument :project_path, GraphQL::Types::ID,
          required: false,
          description: 'Full path of the project containing the workflows.'

        def resolve(**args)
          return [] unless current_user

          workflows = ::Ai::DuoWorkflows::Workflow.for_user(current_user.id)
          if args[:project_path].present?
            project = Project.find_by_full_path(args[:project_path])
            workflows = workflows.for_project(project)
          end

          workflows
        end
      end
    end
  end
end
