# frozen_string_literal: true

module SecretsManagement
  class CreateProjectSecretService < BaseService
    include Gitlab::Utils::StrongMemoize

    def execute(name:, value:, environment:, branch:, description: nil)
      project_secret = ProjectSecret.new(name: name, description: description, project: project,
        branch: branch, environment: environment)

      # Value will be removed in the future and shouldn't be part of the
      # response, so we pass it explicitly to save.
      if project_secret.save(value)
        ServiceResponse.success(payload: { project_secret: project_secret })
      else
        ServiceResponse.error(message: project_secret.errors.full_messages.to_sentence,
          payload: { project_secret: project_secret })
      end
    end
  end
end
