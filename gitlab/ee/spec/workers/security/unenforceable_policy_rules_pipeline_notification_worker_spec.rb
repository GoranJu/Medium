# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::UnenforceablePolicyRulesPipelineNotificationWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:ee_merge_request, source_project: project) }
  let_it_be_with_reload(:pipeline) do
    create(:ci_empty_pipeline,
      status: :success,
      ref: merge_request.source_branch,
      head_pipeline_of: merge_request,
      project: project)
  end

  let_it_be(:other_merge_request) { create(:ee_merge_request) }
  let(:feature_licensed) { true }
  let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
  let!(:approval_project_rule) do
    create(:approval_project_rule, :scan_finding, project: project, scan_result_policy_read: scan_result_policy_read)
  end

  before do
    stub_licensed_features(security_orchestration_policies: feature_licensed)
  end

  describe '#perform' do
    subject(:run_worker) { described_class.new.perform(pipeline_id) }

    let(:pipeline_id) { pipeline.id }

    it 'calls UnenforceablePolicyRulesNotificationService' do
      expect_next_instance_of(Security::UnenforceablePolicyRulesNotificationService, merge_request) do |instance|
        expect(instance).to receive(:execute)
      end

      run_worker
    end

    context 'when pipeline is manual' do
      before do
        pipeline.update!(status: 'manual')
      end

      it 'calls UnenforceablePolicyRulesNotificationService' do
        expect_next_instance_of(Security::UnenforceablePolicyRulesNotificationService, merge_request) do |instance|
          expect(instance).to receive(:execute)
        end

        run_worker
      end
    end

    context 'when pipeline does not exist' do
      let(:pipeline_id) { non_existing_record_id }

      it 'does not call UnenforceablePolicyRulesNotificationService' do
        expect(Security::UnenforceablePolicyRulesNotificationService).not_to receive(:new)

        run_worker
      end
    end

    context 'when feature is not licensed' do
      let(:feature_licensed) { false }

      it 'does not call UnenforceablePolicyRulesNotificationService' do
        expect(Security::UnenforceablePolicyRulesNotificationService).not_to receive(:new)

        run_worker
      end
    end

    context 'when there are no approval rules with scan result policy reads' do
      let!(:approval_project_rule) { nil }

      it 'does not call UnenforceablePolicyRulesNotificationService' do
        expect(Security::UnenforceablePolicyRulesNotificationService).not_to receive(:new)

        run_worker
      end
    end

    context 'when pipeline is still running' do
      before do
        pipeline.update!(status: :running)
      end

      it 'does not call UnenforceablePolicyRulesNotificationService' do
        expect(Security::UnenforceablePolicyRulesNotificationService).not_to receive(:new)

        run_worker
      end
    end

    context 'when the pipeline is not the head_pipeline but ran for diff_head_sha of the merge request' do
      let_it_be(:merge_request_pipeline) do
        create(:ci_empty_pipeline, status: :success, ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha, project: project)
      end

      let(:pipeline_id) { merge_request_pipeline.id }

      it 'calls UnenforceablePolicyRulesNotificationService' do
        expect_next_instance_of(Security::UnenforceablePolicyRulesNotificationService, merge_request) do |instance|
          expect(instance).to receive(:execute)
        end

        run_worker
      end
    end
  end
end
