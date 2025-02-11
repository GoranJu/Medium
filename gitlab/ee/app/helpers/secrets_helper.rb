# frozen_string_literal: true

module SecretsHelper
  def project_secrets_app_data(project)
    {
      project_path: project.full_path,
      project_secrets_settings_path: project_settings_ci_cd_path(
        project, expand_secrets: true, anchor: 'js-secrets-settings'
      ),
      project_id: project.id,
      base_path: project_secrets_path(project)
    }
  end
end
