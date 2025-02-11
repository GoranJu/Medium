# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProvisionProjectSecretsManagerWorker, :gitlab_secrets_manager, feature_category: :secrets_management do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:project) { create(:project) }

    let!(:secrets_manager) { create(:project_secrets_manager, project: project) }

    it 'executes a service' do
      expect(SecretsManagement::ProjectSecretsManager)
        .to receive(:find_by_id).with(secrets_manager.id).and_return(secrets_manager)

      service = instance_double(SecretsManagement::ProvisionProjectSecretsManagerService)
      expect(SecretsManagement::ProvisionProjectSecretsManagerService)
        .to receive(:new).with(secrets_manager).and_return(service)

      expect(service).to receive(:execute)

      worker.perform(secrets_manager.id)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { secrets_manager.id }

      it 'enables the secret engine for the project' do
        expect { perform_idempotent_work }.not_to raise_error

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(secrets_manager.ci_secrets_mount_path)
      end
    end
  end
end
