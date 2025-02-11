# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::ImportExport::AfterExportStrategies::CustomTemplateExportImportStrategy, feature_category: :importers do
  subject { described_class.new(export_into_project_id: project.id) }

  describe 'validations' do
    it 'export_into_project_id must be present' do
      expect(described_class.new(export_into_project_id: nil)).to be_invalid
      expect(described_class.new(export_into_project_id: 1)).to be_valid
    end
  end

  describe '#execute' do
    before do
      allow_next_instance_of(ProjectExportWorker) do |job|
        allow(job).to receive(:jid).and_return(SecureRandom.hex(8))
      end

      stub_licensed_features(custom_project_templates: true)
      allow(RepositoryImportWorker).to receive(:new).and_return(repository_import_worker)
      allow(repository_import_worker).to receive(:perform)
    end

    let!(:project_template) { create(:project, :repository, :with_export, creator: user) }
    let(:project) { create(:project, :import_scheduled, creator: user, import_type: 'gitlab_custom_project_template') }
    let(:user) { build(:user) }
    let(:repository_import_worker) { RepositoryImportWorker.new }

    it 'updates the project import_source with the path to import' do
      file = fixture_file_upload('spec/fixtures/project_export.tar.gz')

      allow(subject).to receive(:export_file).and_return(file)

      subject.execute(user, project_template)

      expect(project.reload.import_export_upload_by_user(user).import_file.file).not_to be_nil
    end

    it 'imports repository' do
      expect(repository_import_worker).to receive(:perform).with(project.id).and_call_original

      subject.execute(user, project_template)

      expect(project_template.repository.ls_files('HEAD')).to eq project.repository.ls_files('HEAD')
    end

    it 'removes the exported project file after the import' do
      expect(project_template).to receive(:remove_export_for_user).with(user)

      subject.execute(user, project_template)
    end

    describe 'export_file' do
      let(:project_template) { create(:project, :with_export, creator: user) }

      before do
        allow(subject).to receive(:project).and_return(project_template)
      end

      it 'returns the path from object storage' do
        subject.execute(user, project_template)

        expect(subject.send(:export_file)).not_to be_nil
      end
    end
  end
end
