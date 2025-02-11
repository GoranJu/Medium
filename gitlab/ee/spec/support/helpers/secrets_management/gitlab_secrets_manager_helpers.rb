# frozen_string_literal: true

module SecretsManagement
  module GitlabSecretsManagerHelpers
    def clean_all_kv_secrets_engines
      client = secrets_manager_client
      client.each_secrets_engine do |path, info|
        next unless info["type"] == "kv"

        client.disable_secrets_engine(path)
      end
    end

    def clean_all_policies
      client = secrets_manager_client
      client.each_acl_policy do |name|
        next unless name.start_with? "project_"

        client.delete_policy(name)
      end
    end

    def provision_project_secrets_manager(secrets_manager)
      ProvisionProjectSecretsManagerService.new(secrets_manager).execute
    end

    def expect_kv_secret_engine_to_be_mounted(path)
      expect { secrets_manager_client.read_secrets_engine_configuration(path) }.not_to raise_error
    end

    def expect_kv_secret_engine_not_to_be_mounted(path)
      expect { secrets_manager_client.read_secrets_engine_configuration(path) }
        .to raise_error(SecretsManagerClient::ApiError)
    end

    def expect_kv_secret_to_have_value(mount_path, path, value)
      stored_data = secrets_manager_client.read_kv_secret_value(mount_path, path)
      expect(stored_data).to eq(value)
    end

    def expect_kv_secret_to_have_custom_metadata(mount_path, path, metadata)
      stored_data = secrets_manager_client.read_secret_metadata(mount_path, path)
      expect(stored_data["custom_metadata"]).to include(metadata)
    end

    def expect_project_secret_not_to_exist(project, name)
      expect(ProjectSecret.from_name(project, name)).to be_nil
    end

    def expect_kv_secret_not_to_exist(mount_path, path)
      expect(secrets_manager_client.read_secret_metadata(mount_path, path)).to be_nil
      expect(secrets_manager_client.read_kv_secret_value(mount_path, path)).to be_nil
    end

    def secrets_manager_client
      TestClient.new
    end

    def create_project_secret(project:, name:, branch:, environment:, value:, description: nil)
      project_secret = ProjectSecret.new(name: name, description: description, project: project,
        branch: branch, environment: environment)

      unless project_secret.save(value)
        raise "project secret creation failed with errors: #{project_secret.errors.full_messages.to_sentence}"
      end

      project_secret
    end
  end
end
