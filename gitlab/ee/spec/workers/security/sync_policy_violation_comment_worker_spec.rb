# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncPolicyViolationCommentWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let(:merge_request_id) { merge_request.id }
    let(:licensed_feature) { true }
    let(:approvals_required) { 1 }
    let_it_be(:protected_branch) { create(:protected_branch, project: project, name: merge_request.target_branch) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read) }
    let_it_be(:scan_finding_project_rule) do
      create(:approval_project_rule, :scan_finding, project: project, protected_branches: [protected_branch],
        scan_result_policy_read: scan_result_policy_read)
    end

    let!(:scan_finding_rule) do
      create(:report_approver_rule, :scan_finding, merge_request: merge_request,
        approval_project_rule: scan_finding_project_rule, approvals_required: approvals_required,
        scan_result_policy_read: scan_result_policy_read)
    end

    let_it_be(:license_scanning_project_rule) do
      create(:approval_project_rule, :license_scanning, project: project, protected_branches: [protected_branch],
        scan_result_policy_read: scan_result_policy_read)
    end

    let!(:license_scanning_rule) do
      create(:report_approver_rule, :license_scanning, merge_request: merge_request,
        approval_project_rule: scan_finding_project_rule, approvals_required: approvals_required,
        scan_result_policy_read: scan_result_policy_read)
    end

    before do
      stub_licensed_features(security_orchestration_policies: licensed_feature)
    end

    subject(:perform) { described_class.new.perform(merge_request_id) }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [merge_request_id] }
    end

    it 'enqueues Security::GeneratePolicyViolationCommentWorker' do
      expect(Security::GeneratePolicyViolationCommentWorker)
        .to receive(:perform_async).with(merge_request.id,
          { 'report_type' => 'scan_finding', 'violated_policy' => false, 'requires_approval' => true })
      expect(Security::GeneratePolicyViolationCommentWorker)
        .to receive(:perform_async).with(merge_request.id,
          { 'report_type' => 'license_scanning', 'violated_policy' => false, 'requires_approval' => true })

      perform
    end

    it_behaves_like 'does not trigger policy bot comment for archived project' do
      subject(:execute) { perform }

      let(:archived_project) { project }
    end

    context 'when there are violations' do
      before do
        create(:scan_result_policy_violation, scan_result_policy_read: scan_result_policy_read,
          merge_request: merge_request, project: project)
      end

      it 'enqueues Security::GeneratePolicyViolationCommentWorker with correct params' do
        expect(Security::GeneratePolicyViolationCommentWorker)
          .to receive(:perform_async).with(merge_request.id,
            { 'report_type' => 'scan_finding', 'violated_policy' => true, 'requires_approval' => true })
        expect(Security::GeneratePolicyViolationCommentWorker)
          .to receive(:perform_async).with(merge_request.id,
            { 'report_type' => 'license_scanning', 'violated_policy' => true, 'requires_approval' => true })

        perform
      end

      context 'when approvals are optional' do
        let(:approvals_required) { 0 }

        it 'enqueues Security::GeneratePolicyViolationCommentWorker with correct params' do
          expect(Security::GeneratePolicyViolationCommentWorker)
            .to receive(:perform_async).with(merge_request.id,
              { 'report_type' => 'scan_finding', 'violated_policy' => true, 'requires_approval' => false })
          expect(Security::GeneratePolicyViolationCommentWorker)
            .to receive(:perform_async).with(merge_request.id,
              { 'report_type' => 'license_scanning', 'violated_policy' => true, 'requires_approval' => false })

          perform
        end
      end
    end

    context 'with a non-existing merge request' do
      let(:merge_request_id) { non_existing_record_id }

      it 'does not enqueue the worker' do
        expect(Security::GeneratePolicyViolationCommentWorker).not_to receive(:perform_async)

        perform
      end
    end

    context 'when feature is not licensed' do
      let(:licensed_feature) { false }

      it 'does not enqueue the worker' do
        expect(Security::GeneratePolicyViolationCommentWorker).not_to receive(:perform_async)

        perform
      end
    end
  end
end
