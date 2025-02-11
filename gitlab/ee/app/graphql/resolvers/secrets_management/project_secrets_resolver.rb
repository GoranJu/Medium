# frozen_string_literal: true

module Resolvers
  module SecretsManagement
    class ProjectSecretsResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource
      include ResolvesProject

      type ::Types::SecretsManagement::ProjectSecretType, null: true

      argument :project_path, GraphQL::Types::ID,
        required: true,
        description: 'Project the secrets belong to.'

      authorize :admin_project_secrets_manager

      def resolve(project_path:)
        project = authorized_find!(project_path: project_path)
        ensure_active_secrets_manager!(project)
        ::SecretsManagement::ProjectSecret.for_project(project)
      end

      private

      def find_object(project_path:)
        resolve_project(full_path: project_path)
      end

      def ensure_active_secrets_manager!(project)
        return if project.secrets_manager&.active?

        raise_resource_not_available_error!('Project secrets manager is not active')
      end
    end
  end
end
