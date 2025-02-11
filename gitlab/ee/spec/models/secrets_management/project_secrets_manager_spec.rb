# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManager, feature_category: :secrets_management do
  subject(:secrets_manager) { build(:project_secrets_manager) }

  it { is_expected.to belong_to(:project) }

  it { is_expected.to validate_presence_of(:project) }

  describe 'state machine' do
    context 'when newly created' do
      it 'defaults to provisioning' do
        secrets_manager.save!
        expect(secrets_manager).to be_provisioning
      end
    end

    context 'when activated' do
      it 'becomes active' do
        secrets_manager.save!
        secrets_manager.activate!
        expect(secrets_manager.reload).to be_active
      end
    end
  end

  describe '#ci_secrets_mount_path' do
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    subject(:path) { secrets_manager.ci_secrets_mount_path }

    context 'when the project belongs to a user namespace' do
      let_it_be(:project) { create(:project) }

      it 'includes the namespace type and ID in the path' do
        expect(path).to eq("user_#{project.namespace.id}/project_#{project.id}/secrets/kv")
      end
    end

    context 'when the project belongs to a group namespace' do
      let_it_be(:project) { create(:project, :in_group) }

      it 'includes the namespace type and ID in the path' do
        expect(path).to eq("group_#{project.namespace.id}/project_#{project.id}/secrets/kv")
      end
    end
  end

  describe '#ci_data_path' do
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    subject(:path) { secrets_manager.ci_data_path("DB_PASS") }

    context 'when the project belongs to a user namespace' do
      let_it_be(:project) { create(:project) }

      it 'does not include any namespace information' do
        expect(path).to eq("explicit/DB_PASS")
      end
    end

    context 'when the project belongs to a group namespace' do
      let_it_be(:project) { create(:project, :in_group) }

      it 'does not include any namespace information' do
        expect(path).to eq("explicit/DB_PASS")
      end
    end
  end

  describe '#ci_full_path' do
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    subject(:path) { secrets_manager.ci_full_path("DB_PASS") }

    context 'when the project belongs to a user namespace' do
      let_it_be(:project) { create(:project) }

      it 'does not include any namespace information' do
        expect(path).to eq("user_#{project.namespace.id}/project_#{project.id}/secrets/kv/data/explicit/DB_PASS")
      end
    end

    context 'when the project belongs to a group namespace' do
      let_it_be(:project) { create(:project, :in_group) }

      it 'does not include any namespace information' do
        expect(path).to eq("group_#{project.namespace.id}/project_#{project.id}/secrets/kv/data/explicit/DB_PASS")
      end
    end
  end
end
