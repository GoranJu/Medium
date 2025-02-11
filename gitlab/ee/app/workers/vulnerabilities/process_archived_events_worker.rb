# frozen_string_literal: true

module Vulnerabilities
  # Ingest archived events to enqueue updating of denormalized column.
  # Check for presence of vulnerabilities to avoid redundant job queueing.

  class ProcessArchivedEventsWorker
    include Gitlab::EventStore::Subscriber

    idempotent!
    deduplicate :until_executing, including_scheduled: true
    data_consistency :sticky

    feature_category :vulnerability_management

    def handle_event(event)
      project_setting = ProjectSetting
        .select(:project_id)
        .has_vulnerabilities
        .find_by_project_id(event.data[:project_id])

      return unless project_setting

      Vulnerabilities::UpdateArchivedOfVulnerabilityReadsService.execute(project_setting.project_id)
      Vulnerabilities::UpdateArchivedOfVulnerabilityStatisticsService.execute(project_setting.project_id)
    end
  end
end
