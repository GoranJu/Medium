# frozen_string_literal: true

module Ci
  module Minutes
    # Track compute usage at the runner level.
    # For gitlab dedicated hosted runners only
    class GitlabHostedRunnerMonthlyUsage < Ci::ApplicationRecord
      include Ci::NamespacedModelName

      belongs_to :project, inverse_of: :hosted_runner_monthly_usages
      belongs_to :root_namespace, class_name: 'Namespace', inverse_of: :hosted_runner_monthly_usages
      belongs_to :runner, class_name: 'Ci::Runner', inverse_of: :hosted_runner_monthly_usages

      validates :runner, presence: true, on: :create
      validates :project, presence: true, on: :create
      validates :root_namespace, presence: true, on: :create

      validates :billing_month, presence: true
      validates :compute_minutes_used,
        numericality: { greater_than_or_equal_to: 0, allow_nil: false, only_float: true },
        presence: true
      validates :runner_duration_seconds, numericality: {
        greater_than_or_equal_to: 0,
        allow_nil: false,
        only_integer: true
      }
      validate :validate_billing_month_format

      private

      def validate_billing_month_format
        return if billing_month.blank?

        return if billing_month == billing_month.beginning_of_month

        errors.add(:billing_month, 'must be the first day of the month')
      end
    end
  end
end
