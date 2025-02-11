# frozen_string_literal: true

module Mutations
  module SecretsManagement
    class ProjectSecretsManagerInitialize < BaseMutation
      graphql_name 'ProjectSecretsManagerInitialize'

      include ResolvesProject

      authorize :admin_project_secrets_manager

      argument :project_path, GraphQL::Types::ID,
        required: true,
        description: 'Project of the secrets manager.'

      field :project_secrets_manager,
        Types::SecretsManagement::ProjectSecretsManagerType,
        null: true,
        description: "Project secrets manager."

      def resolve(project_path:)
        project = authorized_find!(project_path: project_path)

        if Feature.disabled?(:secrets_manager, project)
          raise_resource_not_available_error!("`secrets_manager` feature flag is disabled.")
        end

        result = ::SecretsManagement::InitializeProjectSecretsManagerService
          .new(project, current_user)
          .execute

        if result.success?
          {
            project_secrets_manager: result.payload[:project_secrets_manager],
            errors: []
          }
        else
          {
            project_secrets_manager: nil,
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
