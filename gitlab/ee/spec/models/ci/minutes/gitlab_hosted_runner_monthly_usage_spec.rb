# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::GitlabHostedRunnerMonthlyUsage, factory_default: :keep, feature_category: :hosted_runners do
  let_it_be(:root_namespace) { create_default(:namespace) }
  let_it_be(:project) { create(:project) }
  let_it_be(:runner) { create(:ci_runner, :instance) }

  subject(:usage) do
    described_class.new(
      project: project,
      root_namespace: project.root_namespace,
      runner: runner,
      billing_month: Date.current.beginning_of_month,
      notification_level: :warning,
      compute_minutes_used: 100.5,
      runner_duration_seconds: 6030
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project).inverse_of(:hosted_runner_monthly_usages) }
    it { is_expected.to belong_to(:root_namespace).class_name('Namespace').inverse_of(:hosted_runner_monthly_usages) }
    it { is_expected.to belong_to(:runner).class_name('Ci::Runner').inverse_of(:hosted_runner_monthly_usages) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:runner).on(:create) }
    it { is_expected.to validate_presence_of(:project).on(:create) }
    it { is_expected.to validate_presence_of(:root_namespace).on(:create) }
    it { is_expected.to validate_presence_of(:billing_month) }
    it { is_expected.to validate_presence_of(:compute_minutes_used) }

    it { is_expected.to validate_numericality_of(:compute_minutes_used).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:runner_duration_seconds).is_greater_than_or_equal_to(0).only_integer }

    describe 'billing_month format' do
      context 'when set to the first day of the month' do
        before do
          usage.billing_month = Date.new(2023, 5, 1)
        end

        it 'is valid' do
          expect(usage).to be_valid
        end
      end

      context 'when not set to the first day of the month' do
        before do
          usage.billing_month = Date.new(2023, 5, 2)
        end

        it 'is invalid' do
          expect(usage).to be_invalid
          expect(usage.errors[:billing_month]).to include('must be the first day of the month')
        end
      end

      context 'when billing_month is blank' do
        before do
          usage.billing_month = nil
        end

        it 'is invalid' do
          expect(usage).to be_invalid
          expect(usage.errors[:billing_month]).to include("can't be blank")
        end
      end
    end
  end
end
