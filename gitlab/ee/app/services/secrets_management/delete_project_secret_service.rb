# frozen_string_literal: true

module SecretsManagement
  class DeleteProjectSecretService < BaseService
    include Gitlab::Utils::StrongMemoize

    def execute(name)
      project_secret = ProjectSecret.from_name(project, name)
      return project_secret_not_found_error unless project_secret

      project_secret.delete

      ServiceResponse.success(payload: { project_secret: project_secret })
    end

    private

    def project_secret_not_found_error
      ServiceResponse.error(message: 'Project secret does not exist.', reason: :not_found)
    end
  end
end
