# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::PurgeSecurityScansWithEmptyFindingData,
  :suppress_partitioning_routing_analyzer,
  feature_category: :vulnerability_management do
  let(:succeded_scan_status) { 1 }
  let(:errored_scan_status) { 3 }
  let(:purged_scan_status) { 6 }

  let(:security_findings) { table(:security_findings) }
  let(:security_scans) { table(:security_scans) }
  let(:vulnerability_scanners) { table(:vulnerability_scanners) }
  let(:ci_pipelines) { table(:ci_pipelines, primary_key: :id, database: :ci) }
  let(:organizations) { table(:organizations) }
  let(:projects) { table(:projects) }
  let(:namespaces) { table(:namespaces) }
  let(:ci_builds) { partitioned_table(:p_ci_builds, database: :ci) }

  let(:scanner) { vulnerability_scanners.create!(project_id: project.id, name: 'Foo', external_id: 'foo') }
  let(:organization) { organizations.create!(name: 'organization', path: 'organization') }
  let(:namespace) { namespaces.create!(name: 'test', path: 'test', type: 'Group', organization_id: organization.id) }
  let(:project) do
    projects.create!(
      organization_id: organization.id,
      namespace_id: namespace.id,
      project_namespace_id: namespace.id,
      name: 'test',
      path: 'test'
    )
  end

  let(:pipeline) { ci_pipelines.create!(project_id: project.id, partition_id: 100) }
  let!(:build) do
    ci_builds.create!(project_id: project.id, commit_id: pipeline.id, type: 'Ci::Build', partition_id: 100)
  end

  let!(:security_scan_1) do
    security_scans.create!(
      project_id: project.id,
      pipeline_id: pipeline.id,
      build_id: ci_builds.first.id,
      scan_type: 1,
      status: succeded_scan_status)
  end

  let!(:security_scan_2) do
    security_scans.create!(
      project_id: project.id,
      pipeline_id: pipeline.id,
      build_id: ci_builds.first.id,
      scan_type: 2,
      status: errored_scan_status)
  end

  let!(:security_scan_3) do
    security_scans.create!(
      project_id: project.id,
      pipeline_id: pipeline.id,
      build_id: ci_builds.first.id,
      scan_type: 3,
      status: succeded_scan_status)
  end

  let!(:background_migration) do
    Gitlab::Database::BackgroundMigration::BatchedMigration.create!(
      gitlab_schema: :gitlab_main,
      job_class_name: 'PurgeSecurityScansWithEmptyFindingData',
      table_name: :security_scans,
      column_name: :id,
      job_arguments: [],
      min_value: security_scans.minimum(:id),
      max_value: security_scans.maximum(:id),
      batch_size: 1000,
      sub_batch_size: 100,
      interval: 2.minutes
    )
  end

  let(:migration_attrs) do
    {
      start_id: security_scans.minimum(:id),
      end_id: security_scans.maximum(:id),
      batch_table: :security_scans,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  subject(:perform_migration) { described_class.new(**migration_attrs).perform }

  before do
    security_findings.create!(
      uuid: SecureRandom.uuid,
      scan_id: security_scan_1.id,
      scanner_id: scanner.id,
      severity: 1,
      finding_data: {})

    security_findings.create!(
      uuid: SecureRandom.uuid,
      scan_id: security_scan_2.id,
      scanner_id: scanner.id,
      severity: 1,
      finding_data: {})
  end

  it 'purges the correct `security_scans` records' do
    expect { perform_migration }
      .to change { security_scan_1.reload.status }.from(succeded_scan_status).to(purged_scan_status)
      .and not_change { security_scan_2.reload.status }.from(errored_scan_status)
      .and not_change { security_scan_3.reload.status }.from(succeded_scan_status)
      .and not_change { background_migration.reload.finished? }.from(false)
  end

  context 'when migration encounters with an existing `finding_data`' do
    before do
      security_findings.create!(
        uuid: SecureRandom.uuid,
        scan_id: security_scan_3.id,
        scanner_id: scanner.id,
        severity: 1,
        finding_data: { foo: :bar })
    end

    it 'marks the migration as finished and does not purge the related `security_scans` record' do
      expect { perform_migration }
        .to change { background_migration.reload.finished? }.from(false).to(true)
        .and change { security_scan_1.reload.status }.from(succeded_scan_status).to(purged_scan_status)
        .and not_change { security_scan_2.reload.status }.from(errored_scan_status)
        .and not_change { security_scan_3.reload.status }.from(succeded_scan_status)
    end
  end
end
