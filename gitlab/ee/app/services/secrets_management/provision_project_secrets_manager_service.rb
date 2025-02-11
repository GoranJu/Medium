# frozen_string_literal: true

module SecretsManagement
  class ProvisionProjectSecretsManagerService < BaseService
    ENGINE_TYPE = 'kv-v2'

    def initialize(secrets_manager)
      @secrets_manager = secrets_manager
      @client = SecretsManagerClient.new
    end

    def execute
      client.enable_secrets_engine(secrets_manager.ci_secrets_mount_path, ENGINE_TYPE)
      activate_secrets_manager
      ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
    rescue SecretsManagerClient::ApiError => e
      raise e unless e.message.include?('path is already in use')

      # This scenario may happen in a rare event that the API call to enable the engine succeeds
      # but the actual column update failed due to unexpected reasons (e.g. network hiccups) that
      # will also fail the job. So on job retry, we want to ignore this message and continue
      # with the column update.
      activate_secrets_manager
      ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
    end

    private

    def activate_secrets_manager
      return if secrets_manager.active?

      secrets_manager.activate!
    end

    attr_reader :secrets_manager, :client
  end
end
