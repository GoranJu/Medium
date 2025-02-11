# frozen_string_literal: true

module Security
  class PipelineExecutionProjectSchedule < ApplicationRecord
    include EachBatch

    before_create :set_next_run_at

    self.table_name = 'security_pipeline_execution_project_schedules'

    belongs_to :project
    belongs_to :security_policy, class_name: 'Security::Policy'

    validates :security_policy, uniqueness: { scope: :project_id }
    validates :security_policy, :project, presence: true
    validate :security_policy_is_pipeline_execution_schedule_policy

    scope :for_project, ->(project) { where(project: project) }
    scope :runnable_schedules, -> { where(next_run_at: ...Time.zone.now) }
    scope :ordered_by_next_run_at, -> { order(:next_run_at, :id) }
    scope :including_security_policy_and_project, -> { includes(:security_policy, :project) }

    def cron_timezone
      # ActiveSupport::TimeZone.new will return nil if timezone is invalid
      # https://github.com/rails/rails/blob/dd8f7185faeca6ee968a6e9367f6d8601a83b8db/activesupport/lib/active_support/values/time_zone.rb#L309-L312

      ActiveSupport::TimeZone.new(timezone)&.name || Time.zone.name
    rescue ArgumentError
      # In case self.timezone is nil
      Time.zone.name
    end

    def cron
      security_policy.content.dig('schedule', 'cadence')
    end

    def schedule_next_run!
      set_next_run_at
      save!
    end

    def ci_content
      security_policy.content["content"]
    end

    private

    def timezone
      security_policy.content.dig('schedule', 'timezone')
    end

    def set_next_run_at
      self.next_run_at = calculate_next_run_at(Time.zone.now)
    end

    def calculate_next_run_at(from_time)
      Gitlab::Ci::CronParser
        .new(cron, cron_timezone)
        .next_time_from(from_time)
    end

    def security_policy_is_pipeline_execution_schedule_policy
      return unless security_policy

      return if security_policy.type_pipeline_execution_schedule_policy?

      errors.add(:security_policy,
        _("Security policy must be of type pipeline_execution_schedule_policy"))
    end
  end
end
