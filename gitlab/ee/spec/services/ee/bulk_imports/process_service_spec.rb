# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::ProcessService, feature_category: :importers do
  let_it_be_with_reload(:bulk_import) { create(:bulk_import, source_enterprise: true, source_version: '17.7.0') }

  subject(:service) { described_class.new(bulk_import) }

  context 'when importing a project' do
    it 'does not skip the vulnerabilities tracker' do
      entity = create(:bulk_import_entity, :project_entity, bulk_import: bulk_import)

      service.execute

      skipped_pipelines = entity.trackers.with_status(:skipped).pluck(:relation)

      expect(skipped_pipelines).not_to include("BulkImports::Projects::Pipelines::VulnerabilitiesPipeline")
    end

    context 'when import_vulnerabilities feature flag is disabled' do
      before do
        stub_feature_flags(import_vulnerabilities: false)
      end

      it 'skips the vulnerabilities tracker' do
        entity = create(:bulk_import_entity, :project_entity, bulk_import: bulk_import)

        service.execute

        skipped_pipelines = entity.trackers.with_status(:skipped).pluck(:relation)
        expect(skipped_pipelines).to include("BulkImports::Projects::Pipelines::VulnerabilitiesPipeline")
      end
    end
  end
end
