# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::ScheduleWorker, feature_category: :security_policy_management do
  include ExclusiveLeaseHelpers

  describe '#perform' do
    let_it_be(:schedule) { create(:security_pipeline_execution_project_schedule) }

    subject(:perform) { described_class.new.perform }

    before do
      schedule.update!(next_run_at: 1.hour.ago)
    end

    it_behaves_like 'an idempotent worker' do
      it 'enqueues the run worker' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).to receive(:perform_async).with(schedule.id)

        perform
      end

      it 'updates next_run_at' do
        expect { perform }.to change { schedule.reload.next_run_at }
      end

      context 'with feature disabled' do
        before do
          stub_feature_flags(scheduled_pipeline_execution_policies: false)
        end

        it 'does not enqueue the run worker' do
          expect(Security::PipelineExecutionPolicies::RunScheduleWorker).not_to receive(:perform_async)

          perform
        end
      end
    end

    it 'avoids N+1 queries' do
      schedule.update!(next_run_at: 1.hour.ago)

      control_count = ActiveRecord::QueryRecorder.new { described_class.new.perform }.count

      schedule.update!(next_run_at: 1.hour.ago)
      schedule_2 = create(:security_pipeline_execution_project_schedule)
      schedule_2.update!(next_run_at: 1.hour.ago)

      # +4 queries to update next_run_at for one additional schedule
      expect { described_class.new.perform }.not_to exceed_query_limit(control_count + 4)
    end

    context 'when another worker is still running' do
      let(:lease_key) { described_class::LEASE_KEY }
      let(:timeout) { described_class::LEASE_TIMEOUT }
      let(:lease) { Gitlab::ExclusiveLease.new(lease_key, timeout: timeout).try_obtain }

      it 'does not enqueue the run worker' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).not_to receive(:perform_async)
        expect(lease).not_to be_nil

        perform

        Gitlab::ExclusiveLease.cancel(lease_key, lease)
      end
    end

    context 'if cadence is invalid' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
      let_it_be(:invalid_schedule) do
        create(:security_pipeline_execution_project_schedule, security_policy: security_policy)
      end

      let(:policy_content) do
        {
          content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
          schedule: { cadence: '*/5 * * * *' }
        }.deep_stringify_keys
      end

      before do
        invalid_schedule.update_column(:next_run_at, 1.hour.ago)
        security_policy.update_column(:content, policy_content)
      end

      it 'does not updates next_run_at for invalid schedules' do
        expect { perform }.not_to change { invalid_schedule.reload.next_run_at }
      end

      it 'still updates next_run_at for valid schedules' do
        expect { perform }.to change { schedule.reload.next_run_at }
      end

      it 'does not enqueues the run worker' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).not_to(
          receive(:perform_async).with(invalid_schedule.id)
        )
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).to receive(:perform_async).with(schedule.id)

        perform
      end

      it 'logs the error' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          event: 'scheduled_scan_execution_policy_validation',
          message: 'Invalid cadence',
          project_id: invalid_schedule.project_id,
          cadence: invalid_schedule.cron
        )

        perform
      end
    end
  end
end
