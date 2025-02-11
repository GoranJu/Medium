# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::DeleteProjectSecretService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:service) { described_class.new(project) }
  let(:name) { 'TEST_SECRET' }
  let(:value) { 'the-secret-value' }
  let(:branch) { 'main' }
  let(:environment) { 'prod' }

  subject(:result) { service.execute(name) }

  describe '#execute', :aggregate_failures do
    before do
      provision_project_secrets_manager(secrets_manager)
    end

    context 'when the secret exists' do
      before do
        create_project_secret(
          project: project,
          name: name,
          description: 'test description',
          branch: branch,
          environment: environment,
          value: 'test value'
        )
      end

      it 'deletes the project secret' do
        expect(result).to be_success

        secret = result.payload[:project_secret]
        expect(secret).to be_present
        expect(secret.name).to eq(name)
        expect(secret.project).to eq(project)

        expect_project_secret_not_to_exist(project, name)

        # Validate secret path has been removed from policy.
        expected_policy_name = project.secrets_manager.ci_policy_name_combined(environment, branch)
        actual_policy = secrets_manager_client.get_policy(expected_policy_name)
        expect(actual_policy).not_to be_nil

        expected_path = project.secrets_manager.ci_full_path(name)
        expect(actual_policy.paths).not_to include(expected_path)

        expected_path = project.secrets_manager.ci_metadata_full_path(name)
        expect(actual_policy.paths).not_to include(expected_path)
      end

      context 'when using any environment' do
        let(:environment) { '*' }

        it 'create the correct policy and custom metadata' do
          expect(result).to be_success

          # Validate correct policy has path.
          expected_policy_name = project.secrets_manager.ci_policy_name_branch(branch)
          actual_policy = secrets_manager_client.get_policy(expected_policy_name)
          expect(actual_policy).not_to be_nil

          expected_path = project.secrets_manager.ci_full_path(name)
          expect(actual_policy.paths).not_to include(expected_path)

          expected_path = project.secrets_manager.ci_metadata_full_path(name)
          expect(actual_policy.paths).not_to include(expected_path)
        end
      end

      context 'when using any branch' do
        let(:branch) { '*' }

        it 'create the correct policy and custom metadata' do
          expect(result).to be_success

          # Validate correct policy has path.
          expected_policy_name = project.secrets_manager.ci_policy_name_env(environment)
          actual_policy = secrets_manager_client.get_policy(expected_policy_name)
          expect(actual_policy).not_to be_nil

          expected_path = project.secrets_manager.ci_full_path(name)
          expect(actual_policy.paths).not_to include(expected_path)

          expected_path = project.secrets_manager.ci_metadata_full_path(name)
          expect(actual_policy.paths).not_to include(expected_path)
        end

        context 'and any environmnet' do
          let(:environment) { '*' }

          it 'create the correct policy and custom metadata' do
            expect(result).to be_success

            # Validate correct policy has path.
            expected_policy_name = project.secrets_manager.ci_policy_name_global
            actual_policy = secrets_manager_client.get_policy(expected_policy_name)
            expect(actual_policy).not_to be_nil

            expected_path = project.secrets_manager.ci_full_path(name)
            expect(actual_policy.paths).not_to include(expected_path)

            expected_path = project.secrets_manager.ci_metadata_full_path(name)
            expect(actual_policy.paths).not_to include(expected_path)
          end
        end
      end
    end

    context 'when the secret does not exist' do
      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Project secret does not exist.')
      end
    end
  end
end
