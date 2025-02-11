# frozen_string_literal: true

module Sbom
  class ProcessVulnerabilitiesWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :delayed
    feature_category :software_composition_analysis
    urgency :low
    deduplicate :until_executed
    idempotent!

    def handle_event(event)
      return unless cvs_feature_enabled?(event.data[:pipeline_id])

      CreateVulnerabilitiesService.execute(event.data[:pipeline_id])
    end

    def cvs_feature_enabled?(pipeline_id)
      project_id = Ci::Pipeline.find_by_id(pipeline_id)&.project_id

      Feature.enabled?(:dependency_scanning_using_sbom_reports, Project.actor_from_id(project_id))
    end
  end
end
