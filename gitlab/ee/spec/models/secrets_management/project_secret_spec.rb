# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecret, :gitlab_secrets_manager, feature_category: :secrets_management do
  describe '.for_project' do
    subject(:result) { described_class.for_project(project) }

    before do
      provision_project_secrets_manager(secrets_manager)
      provision_project_secrets_manager(other_secrets_manager)
    end

    let_it_be_with_reload(:project) { create(:project) }
    let_it_be_with_reload(:other_project) { create(:project) }

    let(:secrets_manager) { create(:project_secrets_manager, project: project) }
    let(:other_secrets_manager) { create(:project_secrets_manager, project: other_project) }

    let!(:other_secret) do
      create_project_secret(
        project: other_project,
        name: 'MY_SECRET_1',
        description: 'other test description 1',
        branch: 'master',
        environment: 'production',
        value: 'other test value'
      )
    end

    context 'when project has no secrets yet' do
      it { is_expected.to eq([]) }
    end

    context 'when project has secrets' do
      let!(:secret_1) do
        create_project_secret(
          project: project,
          name: 'MY_SECRET_1',
          description: 'test description 1',
          branch: 'dev-branch-*',
          environment: 'review/*',
          value: 'test value 1'
        )
      end

      let!(:secret_2) do
        create_project_secret(
          project: project,
          name: 'MY_SECRET_2',
          description: 'test description 2',
          branch: 'master',
          environment: 'production',
          value: 'test value 2'
        )
      end

      it 'returns a list of secrets that belong to the given project' do
        expect(result).to contain_exactly(secret_1, secret_2)
      end
    end
  end
end
