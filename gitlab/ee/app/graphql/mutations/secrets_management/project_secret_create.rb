# frozen_string_literal: true

module Mutations
  module SecretsManagement
    class ProjectSecretCreate < BaseMutation
      graphql_name 'ProjectSecretCreate'

      include ResolvesProject

      authorize :admin_project_secrets_manager

      argument :project_path, GraphQL::Types::ID,
        required: true,
        description: 'Project of the secret.'

      argument :name, GraphQL::Types::String,
        required: true,
        description: 'Name of the project secret.'

      argument :description, GraphQL::Types::String,
        required: false,
        description: 'Description of the project secret.'

      argument :value, GraphQL::Types::String,
        required: true,
        description: 'Value of the project secret.'

      argument :environment, GraphQL::Types::String,
        required: true,
        description: 'Environments that can access the secret.'

      argument :branch, GraphQL::Types::String,
        required: true,
        description: 'Branches that can access the secret.'

      field :project_secret,
        Types::SecretsManagement::ProjectSecretType,
        null: true,
        description: "Project secret."

      def resolve(project_path:, name:, value:, environment:, branch:, description: nil)
        project = authorized_find!(project_path: project_path)

        if Feature.disabled?(:secrets_manager, project)
          raise_resource_not_available_error!("`secrets_manager` feature flag is disabled.")
        end

        result = ::SecretsManagement::CreateProjectSecretService
          .new(project, current_user)
          .execute(name: name, description: description, value: value, environment: environment, branch: branch)

        if result.success?
          {
            project_secret: result.payload[:project_secret],
            errors: []
          }
        else
          {
            project_secret: nil,
            errors: errors_on_object(result.payload[:project_secret])
          }
        end
      end

      private

      def find_object(project_path:)
        resolve_project(full_path: project_path)
      end
    end
  end
end
