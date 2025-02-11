# frozen_string_literal: true

module SecretsManagement
  class ProjectSecretsManager < ApplicationRecord
    STATUSES = {
      provisioning: 0,
      active: 1,
      disabled: 2
    }.freeze

    self.table_name = 'project_secrets_managers'

    belongs_to :project

    validates :project, presence: true

    state_machine :status, initial: :provisioning do
      state :provisioning, value: STATUSES[:provisioning]
      state :active, value: STATUSES[:active]
      state :disabled, value: STATUSES[:disabled]

      event :activate do
        transition all - [:active] => :active
      end

      event :disable do
        transition active: :disabled
      end
    end

    def self.server_url
      # Allow setting an external secrets manager URL if necessary. This is
      # useful for GitLab.Com's deployment.
      return Gitlab.config.openbao.url if Gitlab.config.has_key?("openbao") && Gitlab.config.openbao.has_key?("url")

      default_openbao_server_url
    end

    def self.default_openbao_server_url
      "#{Gitlab.config.gitlab.protocol}://#{Gitlab.config.gitlab.host}:8200"
    end
    private_class_method :default_openbao_server_url

    def ci_secrets_mount_path
      [
        namespace_path,
        "project_#{project.id}",
        'secrets',
        'kv'
      ].compact.join('/')
    end

    def ci_data_path(secret_key = nil)
      [
        'explicit',
        secret_key
      ].compact.join('/')
    end

    def ci_full_path(secret_key)
      [
        ci_secrets_mount_path,
        'data',
        ci_data_path(secret_key)
      ].compact.join('/')
    end

    def ci_metadata_full_path(secret_key)
      [
        ci_secrets_mount_path,
        'metadata',
        ci_data_path(secret_key)
      ].compact.join('/')
    end

    def ci_auth_mount
      [
        namespace_path,
        'pipeline_jwt'
      ].compact.join('/')
    end

    def ci_auth_role
      "project_#{project.id}"
    end

    def ci_auth_type
      'jwt'
    end

    def ci_jwt(build)
      Gitlab::Ci::JwtV2.for_build(build, aud: self.class.server_url)
    end

    def ci_policy_name(environment, branch)
      if environment != "*" && branch != "*"
        ci_policy_name_combined(environment, branch)
      elsif environment != "*"
        ci_policy_name_env(environment)
      elsif branch != "*"
        ci_policy_name_branch(branch)
      else
        ci_policy_name_global
      end
    end

    def ci_policy_name_global
      [
        "project_#{project.id}",
        "pipelines",
        "global"
      ].compact.join('/')
    end

    def ci_policy_name_env(environment)
      [
        "project_#{project.id}",
        "pipelines",
        "env",
        Base64.urlsafe_encode64(environment, padding: false)
      ].compact.join('/')
    end

    def ci_policy_name_branch(branch)
      [
        "project_#{project.id}",
        "pipelines",
        "branch",
        Base64.urlsafe_encode64(branch, padding: false)
      ].compact.join('/')
    end

    def ci_policy_name_combined(environment, branch)
      [
        "project_#{project.id}",
        "pipelines",
        "combined",
        "env",
        Base64.urlsafe_encode64(environment, padding: false),
        "branch",
        Base64.urlsafe_encode64(branch, padding: false)
      ].compact.join('/')
    end

    private

    def namespace_path
      [
        project.namespace.type.downcase,
        project.namespace.id.to_s
      ].join('_')
    end
  end
end
