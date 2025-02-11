# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe QueuePurgeSecurityScansWithEmptyFindingData, feature_category: :vulnerability_management do
  let!(:batched_migration) { described_class::MIGRATION }

  let(:succeded_scan_status) { 1 }
  let(:purged_scan_status) { 6 }

  let(:security_findings) { table(:security_findings) }
  let(:security_scans) { table(:security_scans) }
  let(:vulnerability_scanners) { table(:vulnerability_scanners) }
  let(:ci_pipelines) { table(:ci_pipelines, primary_key: :id, database: :ci) }
  let(:projects) { table(:projects) }
  let(:namespaces) { table(:namespaces) }
  let(:ci_builds) { partitioned_table(:p_ci_builds, database: :ci) }

  let(:scanner) { vulnerability_scanners.create!(project_id: project.id, name: 'Foo', external_id: 'foo') }
  let(:namespace) { namespaces.create!(name: 'test', path: 'test', type: 'Group') }
  let(:project) do
    projects.create!(namespace_id: namespace.id, project_namespace_id: namespace.id, name: 'test', path: 'test')
  end

  let(:pipeline) { ci_pipelines.create!(project_id: project.id, partition_id: 100) }
  let!(:build) do
    ci_builds.create!(project_id: project.id, commit_id: pipeline.id, type: 'Ci::Build', partition_id: 100)
  end

  before do
    allow(Gitlab).to receive(:com?).and_return(gitlab_com?)
  end

  context 'for scheduling based on environment' do
    let(:security_scan) do
      security_scans.create!(
        project_id: project.id,
        pipeline_id: pipeline.id,
        build_id: ci_builds.first.id,
        scan_type: 1,
        status: succeded_scan_status)
    end

    let!(:security_finding) do
      security_findings.create!(
        uuid: SecureRandom.uuid,
        scan_id: security_scan.id,
        scanner_id: scanner.id,
        severity: 1,
        finding_data: {})
    end

    context 'when it is on GitLab.com' do
      let(:gitlab_com?) { true }

      it 'does not schedule a new batched migration' do
        reversible_migration do |migration|
          migration.before -> {
            expect(batched_migration).not_to have_scheduled_batched_migration
          }

          migration.after -> {
            expect(batched_migration).not_to have_scheduled_batched_migration
          }
        end
      end
    end

    context 'when it is not on GitLab.com' do
      let(:gitlab_com?) { false }

      it 'schedules a new batched migration' do
        reversible_migration do |migration|
          migration.before -> {
            expect(batched_migration).not_to have_scheduled_batched_migration
          }
          migration.after -> {
            expect(batched_migration).to have_scheduled_batched_migration(
              gitlab_schema: :gitlab_sec,
              table_name: :security_scans,
              column_name: :id,
              interval: described_class::DELAY_INTERVAL,
              batch_size: described_class::BATCH_SIZE,
              sub_batch_size: described_class::SUB_BATCH_SIZE
            )
          }
        end
      end
    end
  end

  context 'for scheduling based on data' do
    let(:gitlab_com?) { false }

    context 'when there is no succeeded scan' do
      let(:security_scan) do
        security_scans.create!(
          project_id: project.id,
          pipeline_id: pipeline.id,
          build_id: ci_builds.first.id,
          scan_type: 1,
          status: purged_scan_status)
      end

      let!(:security_finding) do
        security_findings.create!(
          uuid: SecureRandom.uuid,
          scan_id: security_scan.id,
          scanner_id: scanner.id,
          severity: 1,
          finding_data: { foo: :bar })
      end

      it 'does not schedule a new batched migration' do
        reversible_migration do |migration|
          migration.before -> {
            expect(batched_migration).not_to have_scheduled_batched_migration
          }

          migration.after -> {
            expect(batched_migration).not_to have_scheduled_batched_migration
          }
        end
      end
    end

    context 'when there is a succeeded scan' do
      let!(:security_scan) do
        security_scans.create!(
          project_id: project.id,
          pipeline_id: pipeline.id,
          build_id: ci_builds.first.id,
          scan_type: 1,
          status: succeded_scan_status)
      end

      context 'when there is no associated finding with the security scan' do
        it 'schedules a new batched migration' do
          reversible_migration do |migration|
            migration.before -> {
              expect(batched_migration).not_to have_scheduled_batched_migration
            }

            migration.after -> {
              expect(batched_migration).to have_scheduled_batched_migration(
                gitlab_schema: :gitlab_sec,
                table_name: :security_scans,
                column_name: :id,
                interval: described_class::DELAY_INTERVAL,
                batch_size: described_class::BATCH_SIZE,
                sub_batch_size: described_class::SUB_BATCH_SIZE
              )
            }
          end
        end
      end

      context 'when the first associated finding has `finding_data`' do
        let!(:security_finding) do
          security_findings.create!(
            uuid: SecureRandom.uuid,
            scan_id: security_scan.id,
            scanner_id: scanner.id,
            severity: 1,
            finding_data: { foo: :bar })
        end

        it 'does not schedule a new batched migration' do
          reversible_migration do |migration|
            migration.before -> {
              expect(batched_migration).not_to have_scheduled_batched_migration
            }

            migration.after -> {
              expect(batched_migration).not_to have_scheduled_batched_migration
            }
          end
        end
      end

      context 'when the first associated finding does not have `finding_data`' do
        let!(:security_finding) do
          security_findings.create!(
            uuid: SecureRandom.uuid,
            scan_id: security_scan.id,
            scanner_id: scanner.id,
            severity: 1,
            finding_data: {})
        end

        it 'schedules a new batched migration' do
          reversible_migration do |migration|
            migration.before -> {
              expect(batched_migration).not_to have_scheduled_batched_migration
            }

            migration.after -> {
              expect(batched_migration).to have_scheduled_batched_migration(
                gitlab_schema: :gitlab_sec,
                table_name: :security_scans,
                column_name: :id,
                interval: described_class::DELAY_INTERVAL,
                batch_size: described_class::BATCH_SIZE,
                sub_batch_size: described_class::SUB_BATCH_SIZE
              )
            }
          end
        end
      end
    end
  end
end
