# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::UpdateLicenseApprovalsService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be_with_refind(:merge_request) do
    create(:merge_request, source_project: project)
  end

  let_it_be_with_reload(:pipeline) do
    create(
      :ee_ci_pipeline,
      :success,
      :with_cyclonedx_report,
      project: project,
      merge_requests_as_head_pipeline: [merge_request],
      ref: merge_request.source_branch,
      sha: merge_request.diff_head_sha)
  end

  let_it_be_with_reload(:target_pipeline) do
    create(
      :ee_ci_pipeline,
      :success,
      :with_cyclonedx_report,
      project: project,
      ref: merge_request.target_branch,
      sha: merge_request.diff_base_sha)
  end

  let_it_be(:preexisting_states) { false }

  let(:license_states) { ['newly_detected'] }
  let(:scan_result_policy_read) do
    create(:scan_result_policy_read, project: project, license_states: license_states)
  end

  let!(:license_finding_rule) do
    create(:report_approver_rule, :license_scanning,
      merge_request: merge_request,
      scan_result_policy_read: scan_result_policy_read,
      approvals_required: 1
    )
  end

  subject(:execute) { described_class.new(merge_request, pipeline, preexisting_states).execute }

  shared_examples 'does not require approvals' do
    it 'resets approvals_required in approval rules' do
      expect { execute }.to change { license_finding_rule.reload.approvals_required }.from(1).to(0)
    end
  end

  shared_examples 'requires approval' do
    it 'does not update approval rules' do
      expect { execute }.not_to change { license_finding_rule.reload.approvals_required }
    end
  end

  shared_examples 'persists a violation as warning' do
    it 'persists a violation as warning' do
      execute

      expect(merge_request.scan_result_policy_violations.last).to be_warn
    end
  end

  context 'when merge request is merged' do
    before do
      merge_request.update!(state: 'merged')
    end

    it_behaves_like 'requires approval'
    it_behaves_like 'does not trigger policy bot comment'
  end

  context 'when there are no license scanning rules' do
    before do
      license_finding_rule.delete
    end

    it_behaves_like 'does not trigger policy bot comment'
  end

  describe 'violation data' do
    let(:dependencies) { ('A'..'Z').to_a }

    before do
      allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
        allow(checker).to receive(:execute).and_return({ 'GNU' => dependencies })
      end
    end

    it 'saves a trimmed list of violated dependencies' do
      execute

      expect(merge_request.scan_result_policy_violations.last.violation_data).to eq({
        'context' => {
          'pipeline_ids' => [pipeline.id],
          'target_pipeline_ids' => [target_pipeline.id]
        },
        'violations' => {
          'license_scanning' => {
            'GNU' => dependencies.first(Security::ScanResultPolicyViolation::MAX_VIOLATIONS + 1)
          }
        }
      })
    end
  end

  context 'for preexisting states' do
    let_it_be(:preexisting_states) { true }
    let_it_be(:pipeline) { nil }
    let(:license_states) { ['detected'] }

    before do
      allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
        allow(checker).to receive(:execute).and_return({ 'GNU' => ['A'] })
      end
    end

    it_behaves_like 'requires approval'
    it_behaves_like 'triggers policy bot comment', :license_scanning, true

    it 'logs the violated rules' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(message: 'Updating MR approval rule'))

      execute
    end

    it 'saves violation without pipeline id' do
      execute

      expect(merge_request.scan_result_policy_violations.last.violation_data).to eq({
        'context' => {
          'pipeline_ids' => [],
          'target_pipeline_ids' => [target_pipeline.id]
        },
        'violations' => {
          'license_scanning' => {
            'GNU' => ['A']
          }
        }
      })
    end

    context 'when there are no violations' do
      before do
        allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
          allow(checker).to receive(:execute).and_return(nil)
        end
      end

      it_behaves_like 'does not require approvals'
      it_behaves_like 'triggers policy bot comment', :license_scanning, false
      it_behaves_like 'merge request without scan result violations'

      it 'does not call logger' do
        expect(Gitlab::AppJsonLogger).not_to receive(:info)

        execute
      end
    end

    context 'when target branch pipeline is nil' do
      before do
        target_pipeline.update!(ref: merge_request.source_branch)
      end

      context 'when fail_open is true' do
        before do
          license_finding_rule.scan_result_policy_read.update!(fallback_behavior: { fail: 'open' })
        end

        it_behaves_like 'does not require approvals'
        it_behaves_like 'triggers policy bot comment', :license_scanning, true
        it_behaves_like 'persists a violation as warning'
      end
    end
  end

  context 'for newly_detected states' do
    before do
      allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
        allow(checker).to receive(:execute).and_return({ 'GNU' => ['A'] })
      end
    end

    context 'when the pipeline has no license report' do
      before do
        allow(::Gitlab::LicenseScanning).to receive(:scanner_for_pipeline).and_return(
          instance_double('Gitlab::LicenseScanning::SbomScanner', report: nil, results_available?: false)
        )
      end

      it_behaves_like 'requires approval'
      it_behaves_like 'does not trigger policy bot comment'
    end

    context 'when there are no violations' do
      before do
        allow_next_instance_of(Security::ScanResultPolicies::LicenseViolationChecker) do |checker|
          allow(checker).to receive(:execute).and_return(nil)
        end
      end

      it_behaves_like 'does not require approvals'
      it_behaves_like 'triggers policy bot comment', :license_scanning, false
    end

    context 'when target branch pipeline is nil' do
      before do
        target_pipeline.update!(ref: merge_request.source_branch)
      end

      context 'when there are multiple pipelines without reports and one related pipeline' do
        before do
          create_list(:ee_ci_pipeline, 10, :success, project: project, ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha, source: :schedule)
        end

        let_it_be(:related_target_pipeline) do
          create(
            :ee_ci_pipeline,
            :success,
            :with_dependency_scanning_feature_branch,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha)
        end

        it_behaves_like 'requires approval'
      end

      context 'when fail_open is true' do
        before do
          license_finding_rule.scan_result_policy_read.update!(fallback_behavior: { fail: 'open' })
        end

        it_behaves_like 'does not require approvals'
        it_behaves_like 'triggers policy bot comment', :license_scanning, true
        it_behaves_like 'persists a violation as warning'
      end
    end
  end
end
