# frozen_string_literal: true

module Mutations
  module SecretsManagement
    class ProjectSecretDelete < BaseMutation
      graphql_name 'ProjectSecretDelete'

      include ResolvesProject

      authorize :admin_project_secrets_manager

      argument :project_path, GraphQL::Types::ID,
        required: true,
        description: 'Project of the secret.'

      argument :name, GraphQL::Types::String,
        required: true,
        description: 'Name of the project secret.'

      field :project_secret,
        Types::SecretsManagement::ProjectSecretType,
        null: true,
        description: "Deleted project secret."

      def resolve(project_path:, name:)
        project = authorized_find!(project_path: project_path)

        if Feature.disabled?(:secrets_manager, project)
          raise_resource_not_available_error!("`secrets_manager` feature flag is disabled.")
        end

        result = ::SecretsManagement::DeleteProjectSecretService
          .new(project, current_user)
          .execute(name)

        if result.success?
          {
            project_secret: result.payload[:project_secret],
            errors: []
          }
        elsif result.reason == :not_found
          raise_resource_not_available_error!("Project secret does not exist.")
        else
          {
            project_secret: nil,
            errors: [result.message]
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
