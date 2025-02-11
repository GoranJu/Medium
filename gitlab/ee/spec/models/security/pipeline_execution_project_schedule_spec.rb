# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionProjectSchedule, feature_category: :security_policy_management do
  describe 'validations' do
    let(:schedule) { build(:security_pipeline_execution_project_schedule) }

    subject { schedule }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:security_policy) }
    it { is_expected.to validate_presence_of(:project) }

    describe 'uniqueness validation' do
      let(:schedule) { create(:security_pipeline_execution_project_schedule) }

      it { is_expected.to validate_uniqueness_of(:security_policy).scoped_to(:project_id) }
    end

    context 'when security policy is not a pipeline_execution_schedule_policy' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_policy) }
      let(:schedule) { build(:security_pipeline_execution_project_schedule, security_policy: security_policy) }

      it { is_expected.not_to be_valid }
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:security_policy).class_name('Security::Policy') }
  end

  describe 'scopes' do
    describe '.for_project' do
      let_it_be(:project) { create(:project) }
      let_it_be(:schedule) { create(:security_pipeline_execution_project_schedule, project: project) }
      let_it_be(:other_schedule) { create(:security_pipeline_execution_project_schedule) }

      it 'returns schedules for the given project' do
        expect(described_class.for_project(project)).to contain_exactly(schedule)
      end
    end

    describe '.runnable_schedules' do
      let_it_be(:runnable_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:future_schedule) { create(:security_pipeline_execution_project_schedule) }

      before do
        runnable_schedule.update!(next_run_at: 1.hour.ago)
        future_schedule.update!(next_run_at: 1.hour.from_now)
      end

      it 'returns schedules that are due to run' do
        expect(described_class.runnable_schedules).to contain_exactly(runnable_schedule)
      end
    end

    describe '.ordered_by_next_run_at' do
      let_it_be(:monthly_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:weekly_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:daily_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:daily_schedule_2) { create(:security_pipeline_execution_project_schedule) }

      before do
        monthly_schedule.update!(next_run_at: Time.zone.now + 1.month)
        weekly_schedule.update!(next_run_at: Time.zone.now + 1.week)

        # Use the same time for both records to ensure the order by id is correct.
        daily_schedule_time = Time.zone.now + 1.day
        daily_schedule.update!(next_run_at: daily_schedule_time)
        daily_schedule_2.update!(next_run_at: daily_schedule_time)
      end

      it 'returns schedules ordered by next_run_at and id' do
        expect(described_class.ordered_by_next_run_at).to eq(
          [daily_schedule, daily_schedule_2, weekly_schedule, monthly_schedule]
        )
      end
    end

    describe '.including_security_policy_and_project' do
      let_it_be(:schedule_1) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:schedule_2) { create(:security_pipeline_execution_project_schedule) }

      it 'preloads security_policy and project' do
        recorder = ActiveRecord::QueryRecorder.new do
          schedules = described_class.including_security_policy_and_project

          schedules.each do |schedule|
            schedule.security_policy
            schedule.project
          end
        end

        # 1. Load schedules
        # 2. Load security_policy
        # 3. Load project
        expect(recorder.count).to eq(3)
      end
    end
  end

  describe 'callbacks' do
    describe 'update next_run_at on create', time_travel_to: '2024-12-20 00:00:00' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      let(:schedule) { build(:security_pipeline_execution_project_schedule, security_policy: security_policy) }

      subject(:save!) { schedule.save! }

      it 'sets next_run_at to the next cron run based on current time' do
        save!

        expect(schedule.next_run_at).to eq(Time.zone.now + 1.day)
      end
    end
  end

  describe '#cron_timezone' do
    let(:schedule) { build(:security_pipeline_execution_project_schedule) }

    subject { schedule.cron_timezone }

    context 'when timezone is not set' do
      it { is_expected.to eq(Time.zone.name) }
    end

    context 'when timezone is valid' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      let_it_be(:policy_content) do
        {
          content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
          schedule: { cadence: '0 0 * * *', timezone: 'America/New_York' }
        }.deep_stringify_keys
      end

      let(:schedule) { build(:security_pipeline_execution_project_schedule, security_policy: security_policy) }

      before do
        security_policy.update!(content: policy_content)
      end

      it { is_expected.to eq('America/New_York') }
    end

    context 'when timezone is invalid' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      let(:policy_content) do
        {
          content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
          schedule: { cadence: '0 0 * * *', timezone: 'Invalid/Timezone' }
        }
      end

      let(:schedule) { build(:security_pipeline_execution_project_schedule, security_policy: security_policy) }

      it { is_expected.to eq(Time.zone.name) }
    end
  end

  describe '#cron' do
    let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

    let(:policy_content) do
      {
        content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
        schedule: { cadence: '0 0 1 * *', timezone: 'Invalid/Timezone' }
      }
    end

    let(:schedule) { build(:security_pipeline_execution_project_schedule, security_policy: security_policy) }

    before do
      security_policy.update!(content: policy_content)
    end

    it 'returns the cadence value from the security policy' do
      expect(schedule.cron).to eq('0 0 1 * *')
    end
  end

  describe 'schedule_next_run!', time_travel_to: '2024-12-20 00:00:00' do
    let(:schedule) { create(:security_pipeline_execution_project_schedule) }

    subject(:schedule_next_run!) { schedule.schedule_next_run! }

    it 'updates next_run_at to the next cron run based on current time' do
      schedule_next_run!

      expect(schedule.next_run_at).to eq(Time.zone.now + 1.day)
    end

    context 'when new next_run_at value would result in a time in the past' do
      before do
        schedule.next_run_at = 1.year.ago
      end

      it 'updates next_run_at to the next cron run based on current time' do
        schedule_next_run!

        expect(schedule.next_run_at).to eq(Time.zone.now + 1.day)
      end
    end

    context 'when next_run_at is nil' do
      before do
        schedule.next_run_at = nil
      end

      it 'sets next_run_at to the next cron run based on current time' do
        schedule_next_run!

        expect(schedule.next_run_at).to eq(Time.zone.now + 1.day)
      end
    end
  end

  describe '#ci_content' do
    subject(:ci_content) { build(:security_pipeline_execution_project_schedule).ci_content }

    it 'returns the security policy CI config content' do
      expect(ci_content).to eq(
        'include' => [{ 'project' => 'compliance-project', 'file' => 'compliance-pipeline.yml' }])
    end
  end
end
