# frozen_string_literal: true

require "spec_helper"

RSpec.describe SecretsHelper, feature_category: :secrets_management do
  let_it_be(:project) { build_stubbed(:project) }
  let_it_be(:group) { build_stubbed(:group) }

  describe '#project_secrets_app_data' do
    subject { helper.project_secrets_app_data(project) }

    it 'returns expected data' do
      expect(subject).to include({
        project_path: project.full_path,
        project_id: project.id,
        project_secrets_settings_path: project_settings_ci_cd_path(project, expand_secrets: true,
          anchor: 'js-secrets-settings'),
        base_path: project_secrets_path(project)
      })
    end
  end
end
