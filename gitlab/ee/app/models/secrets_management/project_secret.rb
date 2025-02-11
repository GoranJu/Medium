# frozen_string_literal: true

module SecretsManagement
  class ProjectSecret
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    attribute :project

    attribute :name, :string
    attribute :description, :string
    attribute :branch, :string
    attribute :environment, :string

    validates :project, presence: true
    validates :name, presence: true
    validates :branch, presence: true
    validates :environment, presence: true
    validate :ensure_active_secrets_manager

    delegate :secrets_manager, to: :project

    def self.for_project(project)
      secrets_manager = project.secrets_manager
      client.list_secrets(secrets_manager.ci_secrets_mount_path, secrets_manager.ci_data_path) do |data|
        custom_metadata = data.dig("metadata", "custom_metadata")

        new(
          name: data["key"],
          project: project,
          description: custom_metadata["description"],
          environment: custom_metadata["environment"],
          branch: custom_metadata["branch"]
        )
      end
    end

    def self.from_name(project, name)
      secrets_manager = project.secrets_manager
      secret = client.read_secret_metadata(secrets_manager.ci_secrets_mount_path, secrets_manager.ci_data_path(name))

      return if secret.nil?

      new(
        name: name,
        project: project,
        description: secret["custom_metadata"]["description"],
        environment: secret["custom_metadata"]["environment"],
        branch: secret["custom_metadata"]["branch"]
      )
    end

    def self.client
      @client ||= SecretsManagerClient.new
    end

    def save(value)
      return false unless valid?

      client = SecretsManagerClient.new

      # The follow API calls are ordered such that they fail closed: first we
      # create the secret and its metadata and then attach policy to it. If we
      # fail to attach policy, no pipelines can access it and only project-level
      # users can modify it in the future. Updating a secret to set missing
      # branch and environments will then allow pipelines to access the secret.

      # Create the secret itself.
      custom_metadata = { environment: environment, branch: branch, description: description }.compact
      client.create_kv_secret(
        secrets_manager.ci_secrets_mount_path,
        secrets_manager.ci_data_path(name),
        value,
        custom_metadata
      )

      # Add it to the CI policy for the specified environment and branch.
      policy_name = secrets_manager.ci_policy_name(environment, branch)
      p = client.get_policy(policy_name)
      p.add_capability(secrets_manager.ci_full_path(name), "read")
      p.add_capability(secrets_manager.ci_metadata_full_path(name), "read")
      client.set_policy(p)

      true
    rescue SecretsManagerClient::ApiError => e
      raise e unless e.message.include?('check-and-set parameter did not match the current version')

      errors.add(:base, 'Project secret already exists.')
      false
    end

    def delete
      client.delete_kv_secret(
        secrets_manager.ci_secrets_mount_path,
        secrets_manager.ci_data_path(name)
      )

      policy_name = secrets_manager.ci_policy_name(environment, branch)
      p = client.get_policy(policy_name)
      p.remove_capability(secrets_manager.ci_full_path(name), "read")
      p.remove_capability(secrets_manager.ci_metadata_full_path(name), "read")
      client.set_policy(p)
    end

    def ==(other)
      other.is_a?(self.class) && attributes == other.attributes
    end

    private

    def ensure_active_secrets_manager
      errors.add(:base, 'Project secrets manager is not active.') unless project.secrets_manager&.active?
    end

    def client
      self.class.client
    end
  end
end
