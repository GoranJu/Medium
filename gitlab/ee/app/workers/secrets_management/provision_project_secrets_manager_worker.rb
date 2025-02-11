# frozen_string_literal: true

module SecretsManagement
  class ProvisionProjectSecretsManagerWorker
    include ApplicationWorker

    data_consistency :sticky

    urgency :high

    idempotent!

    feature_category :secrets_management

    def perform(project_secrets_manager_id)
      ProjectSecretsManager.find_by_id(project_secrets_manager_id).try do |secrets_manager|
        ProvisionProjectSecretsManagerService.new(secrets_manager).execute
      end
    end
  end
end
