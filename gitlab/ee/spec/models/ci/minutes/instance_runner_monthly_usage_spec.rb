# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::InstanceRunnerMonthlyUsage, feature_category: :hosted_runners do
  let_it_be(:root_namespace) { create(:namespace) }
  let_it_be(:project) { create(:project, namespace: root_namespace) }
  let_it_be(:runner) { create(:ci_runner, :instance) }

  let(:usage) do
    build(
      :ci_instance_runner_monthly_usage,
      runner_id: runner.id,
      root_namespace_id: root_namespace.id,
      project_id: project.id
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:root_namespace) }
    it { is_expected.to belong_to(:runner) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project).on(:create) }
    it { is_expected.not_to validate_presence_of(:project).on(:update) }
    it { is_expected.to validate_presence_of(:runner).on(:create) }
    it { is_expected.not_to validate_presence_of(:runner).on(:update) }
    it { is_expected.to validate_presence_of(:root_namespace) }
    it { is_expected.to validate_presence_of(:billing_month) }
    it { is_expected.to validate_numericality_of(:compute_minutes_used).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:runner_duration_seconds) }
    it { is_expected.to validate_numericality_of(:runner_duration_seconds).is_greater_than_or_equal_to(0).only_integer }

    describe '#validate_billing_month_format' do
      let(:usage) do
        build(
          :ci_instance_runner_monthly_usage,
          runner_id: runner.id,
          root_namespace_id: root_namespace.id,
          project_id: project.id
        )
      end

      context 'when billing_month is the first day of the month' do
        it 'is valid' do
          usage.billing_month = Date.new(2023, 5, 1)
          expect(usage).to be_valid
        end
      end

      context 'when billing_month is not the first day of the month' do
        it 'is invalid' do
          usage.billing_month = Date.new(2023, 5, 2)
          expect(usage).to be_invalid
          expect(usage.errors[:billing_month]).to include('must be the first day of the month')
        end
      end

      context 'when billing_month is blank' do
        it 'is invalid' do
          usage.billing_month = nil
          expect(usage).to be_invalid
          expect(usage.errors[:billing_month]).to include("can't be blank")
        end
      end
    end
  end
end
