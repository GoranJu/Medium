# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProvisionProjectSecretsManagerService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:service) { described_class.new(secrets_manager) }

  subject(:result) { service.execute }

  describe '#execute' do
    let(:client) { SecretsManagement::SecretsManagerClient.new }

    it 'enables the secret engine for the project and activates the secret manager', :aggregate_failures do
      expect(result).to be_success

      expect(secrets_manager.reload).to be_active

      expect_kv_secret_engine_to_be_mounted(secrets_manager.ci_secrets_mount_path)
    end

    context 'when the secrets engine has already been enabled' do
      before do
        client.enable_secrets_engine(secrets_manager.ci_secrets_mount_path, described_class::ENGINE_TYPE)
      end

      it 'still activates the secrets manager' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(secrets_manager.ci_secrets_mount_path)
      end
    end
  end
end
