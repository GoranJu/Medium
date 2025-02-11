# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::MarkAsResolvedService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  describe '#execute' do
    context 'when using a vulnerability scanner' do
      let(:command) { described_class.new(pipeline, scanner, ingested_ids) }
      let(:ingested_ids) { [] }
      let_it_be(:scanner) do
        create(:vulnerabilities_scanner, project: project, name: 'SAST scanner', external_id: 'semgrep')
      end

      let(:pipeline) { create(:ee_ci_pipeline) }

      context 'when there is a vulnerability to be resolved' do
        let_it_be(:vulnerability) do
          create(:vulnerability, :sast,
            project: project,
            present_on_default_branch: true,
            resolved_on_default_branch: false,
            findings: [create(:vulnerabilities_finding, project: project, scanner: scanner)]
          )
        end

        it 'resolves non-generic vulnerabilities detected by the scanner' do
          command.execute

          expect(vulnerability.reload).to be_resolved_on_default_branch
        end

        it 'calls AutoResolveService on missing_ids' do
          expect_next_instance_of(Vulnerabilities::AutoResolveService, project, [vulnerability.id], 1000) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.success(payload: { count: 1 }))
          end

          command.execute
        end

        it 'does not call AutoResolveService when count of resolved vulnerabilities is over limit' do
          command.instance_variable_set(:@auto_resolved_count, described_class::AUTO_RESOLVE_LIMIT + 1)

          expect(Vulnerabilities::AutoResolveService).not_to receive(:new)

          command.execute
        end

        it 'stops calling AutoResolveService when count of resolved vulnerabilities is over limit' do
          # Setting the BATCH_SIZE to 1 forces us to handle each vulnerability one by one.
          # The first vulnerability that we handle should be auto resolved.
          stub_const("#{described_class.name}::BATCH_SIZE", 1)
          # Setting AUTO_RESOLVE_LIMIT to 1 is what lets us check that the limit works as expected
          # By running in batches of 1, the first vulnerability should be auto-resolved and the
          # second should not.
          stub_const("#{described_class.name}::AUTO_RESOLVE_LIMIT", 1)

          # The first vulnerability is created on L16.
          second_vulnerability = create(:vulnerability, :sast,
            project: project,
            present_on_default_branch: true,
            resolved_on_default_branch: false,
            findings: [create(:vulnerabilities_finding, project: project, scanner: scanner)]
          )

          # This expectation doesn't fail if it is called multiple times, it fails if it is called with different
          # arguments to those set up here. Both vulnerabilities will have different IDs, so if it **is** called
          # twice then it will fail.
          # This expectation confirms that the first vulnerability is successfully passed on to the auto-resolve
          # service and the second is not.
          expect_next_instance_of(Vulnerabilities::AutoResolveService, project, [vulnerability.id], 1) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.success(payload: { count: 1 }))
          end

          command.execute

          # Finally, check that both vulnerabilities are still resolved_on_default_branch as before.
          expect(vulnerability.reload).to be_resolved_on_default_branch
          expect(second_vulnerability.reload).to be_resolved_on_default_branch
        end

        it 'creates a RepresentationInformation record for the resolved vulnerability' do
          vulnerability = create(
            :vulnerability,
            :sast,
            project: project,
            present_on_default_branch: true,
            resolved_on_default_branch: false,
            findings: [create(:vulnerabilities_finding, :with_pipeline, project: project,
              scanner: scanner)]
          )

          command.execute

          expect(vulnerability.reload).to be_resolved_on_default_branch
          representation_info = Vulnerabilities::RepresentationInformation
                                  .find_or_initialize_by(vulnerability_id: vulnerability.id)
          representation_info.update!(
            project_id: vulnerability.project_id,
            resolved_in_commit_sha: vulnerability.findings.first.sha
          )
          expect(representation_info.project_id).to eq(vulnerability.project_id)
          expect(representation_info.resolved_in_commit_sha).to eq(vulnerability.findings.first.sha)
        end
      end

      context 'with multiple vulnerabilities' do
        let_it_be(:num_vulnerabilities) { 3 }
        let_it_be(:user) { create(:user) }
        let_it_be(:vulnerabilities) do
          create_list(:vulnerability,
            num_vulnerabilities,
            :with_scanner,
            :sast,
            scanner: scanner,
            project: project,
            author: user,
            present_on_default_branch: true,
            resolved_on_default_branch: false
          )
        end

        it 'emits event for each vulnerability' do
          expect { command.execute }.to trigger_internal_events('vulnerability_no_longer_detected_on_default_branch')
            .with(project: project).exactly(num_vulnerabilities).times
            .and increment_usage_metrics(
              'counts.count_total_vulnerability_no_longer_detected_on_default_branch_weekly',
              'counts.count_total_vulnerability_no_longer_detected_on_default_branch_monthly'
            ).by(num_vulnerabilities)
        end
      end

      it 'does not resolve vulnerabilities detected by a different scanner' do
        vulnerability = create(:vulnerability, :sast, project: project, present_on_default_branch: true)

        command.execute

        expect(vulnerability.reload).not_to be_resolved_on_default_branch
      end

      context 'when a vulnerability requires manual resolution' do
        it 'does not resolve generic vulnerabilities' do
          vulnerability = create(:vulnerability, :generic, project: project)

          command.execute

          expect(vulnerability.reload).not_to be_resolved_on_default_branch
        end

        it 'does not resolve secret_detection vulnerabilities' do
          vulnerability = create(:vulnerability, :secret_detection, project: project)

          command.execute

          expect(vulnerability.reload).not_to be_resolved_on_default_branch
        end
      end

      context 'when a vulnerability is already ingested' do
        let_it_be(:ingested_vulnerability) { create(:vulnerability, project: project) }

        before do
          ingested_ids << ingested_vulnerability.id
        end

        it 'does not resolve ingested vulnerabilities' do
          command.execute

          expect(ingested_vulnerability.reload).not_to be_resolved_on_default_branch
        end
      end

      context 'when a vulnerability has been created by Continuous Vulnerability Scanning' do
        let_it_be(:cvs_scanner) do
          create(:vulnerabilities_scanner, project: project,
            name: 'CVS scanner',
            external_id: 'gitlab-sbom-vulnerability-scanner'
          )
        end

        let_it_be(:cvs_ds_vulnerability) do
          create(:vulnerability, :dependency_scanning, project: project,
            present_on_default_branch: true,
            resolved_on_default_branch: false,
            findings: [create(:vulnerabilities_finding, project: project, scanner: cvs_scanner)]
          )
        end

        let_it_be(:cvs_cs_vulnerability) do
          create(:vulnerability, :container_scanning, project: project,
            present_on_default_branch: true,
            resolved_on_default_branch: false,
            findings: [create(:vulnerabilities_finding, project: project, scanner: cvs_scanner)]
          )
        end

        context 'when ingesting vulnerabilities from a Dependency Scanning scanner' do
          using RSpec::Parameterized::TableSyntax

          where(:scanner_id) do
            described_class::DS_SCANNERS_EXTERNAL_IDS.map { |id| [id] }
          end

          with_them do
            let(:scanner) do
              create(:vulnerabilities_scanner, project: project,
                name: scanner_id,
                external_id: scanner_id
              )
            end

            it 'resolves CVS vulnerabilities of the Dependency Scanning report type' do
              command.execute

              expect(cvs_ds_vulnerability.reload).to be_resolved_on_default_branch
              expect(cvs_cs_vulnerability.reload).not_to be_resolved_on_default_branch
            end
          end
        end

        context 'when ingesting vulnerabilities from a Container Scanning scanner' do
          let_it_be(:scanner) do
            create(:vulnerabilities_scanner, project: project,
              name: 'CS scanner',
              external_id: 'trivy'
            )
          end

          it 'resolves CVS vulnerabilities of the Container Scanning report type' do
            command.execute

            expect(cvs_cs_vulnerability.reload).to be_resolved_on_default_branch
            expect(cvs_ds_vulnerability.reload).not_to be_resolved_on_default_branch
          end
        end

        context 'when ingesting vulnerabilities from other scanners' do
          let_it_be(:scanner) { Vulnerabilities::Scanner.find_or_create_by!(project: project, external_id: 'semgrep') }

          it 'does not resolve CVS vulnerabilities' do
            command.execute

            expect(cvs_cs_vulnerability.reload).not_to be_resolved_on_default_branch
            expect(cvs_ds_vulnerability.reload).not_to be_resolved_on_default_branch
          end
        end

        context 'when the vulnerability is still reported' do
          let_it_be(:scanner) do
            create(:vulnerabilities_scanner, project: project,
              name: 'CS scanner',
              external_id: 'trivy'
            )
          end

          before do
            ingested_ids << cvs_cs_vulnerability.id
          end

          it 'does not resolve CVS vulnerabilities' do
            command.execute

            expect(cvs_cs_vulnerability.reload).not_to be_resolved_on_default_branch
            expect(cvs_ds_vulnerability.reload).not_to be_resolved_on_default_branch
          end
        end
      end

      context 'when the report type is specified' do
        let_it_be(:sbom_scanner) do
          create(:vulnerabilities_scanner, :sbom_scanner, project: project)
        end

        let(:command) { described_class.new(pipeline, sbom_scanner, ingested_ids, :dependency_scanning) }

        let_it_be(:ds_vulnerability) do
          create(:vulnerability, :dependency_scanning, :with_scanner,
            project: project,
            present_on_default_branch: true,
            resolved_on_default_branch: false,
            scanner: sbom_scanner)
        end

        let_it_be(:cs_vulnerability) do
          create(:vulnerability, :container_scanning, :with_scanner,
            project: project,
            present_on_default_branch: true,
            resolved_on_default_branch: false,
            scanner: sbom_scanner)
        end

        it 'resolve vulnerabilities with the corresponding report type' do
          expect { command.execute }.to change { ds_vulnerability.reload.resolved_on_default_branch }.to(true)
        end

        it 'does not resolve vulnerabilities with a different report type' do
          expect { command.execute }.not_to change { cs_vulnerability.reload.resolved_on_default_branch }.from(false)
        end
      end
    end

    context 'when a scanner is not available' do
      let(:command) { described_class.new(nil, nil, []) }

      it 'does not resolve any vulnerabilities' do
        vulnerability = create(:vulnerability, :sast,
          project: project,
          present_on_default_branch: true,
          resolved_on_default_branch: false,
          findings: []
        )

        command.execute

        expect(vulnerability.reload).not_to be_resolved_on_default_branch
      end
    end
  end
end
