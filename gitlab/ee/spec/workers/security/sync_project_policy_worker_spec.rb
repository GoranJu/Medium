# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncProjectPolicyWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:security_policy) { create(:security_policy) }

  let(:project_id) { project.id }
  let(:security_policy_id) { security_policy.id }
  let(:policy_changes) { { 'some_key' => 'some_value' } }

  describe '#perform' do
    subject(:perform) { described_class.new.perform(project_id, security_policy_id, policy_changes) }

    context 'when project and security policy exist' do
      it 'calls the SyncProjectService with correct parameters' do
        sync_service = instance_double(Security::SecurityOrchestrationPolicies::SyncProjectService)
        expect(Security::SecurityOrchestrationPolicies::SyncProjectService).to receive(:new)
          .with(security_policy: security_policy, project: project, policy_changes: policy_changes.deep_symbolize_keys)
          .and_return(sync_service)
        expect(sync_service).to receive(:execute)

        perform
      end
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'does not call the SyncProjectService' do
        expect(Security::SecurityOrchestrationPolicies::SyncProjectService).not_to receive(:new)

        perform
      end
    end

    context 'when security policy does not exist' do
      let(:security_policy_id) { non_existing_record_id }

      it 'does not call the SyncProjectService' do
        expect(Security::SecurityOrchestrationPolicies::SyncProjectService).not_to receive(:new)

        perform
      end
    end
  end

  describe 'deduplication' do
    let(:policy_changes_2) { { 'some_key' => 'some_other_value' } }
    let(:job_a) { { 'class' => described_class.name, 'args' => [project_id, security_policy_id, policy_changes] } }
    let(:job_b) { { 'class' => described_class.name, 'args' => [project_id, security_policy_id, policy_changes_2] } }

    let(:duplicate_job_a) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_a, 'test') }
    let(:duplicate_job_b) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_b, 'test') }

    specify do
      expect(duplicate_job_a.send(:idempotency_key) == duplicate_job_b.send(:idempotency_key)).to be(true)
    end
  end
end
