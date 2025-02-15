# frozen_string_literal: true

module Search
  module Zoekt
    class TaskFailedEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      urgency :low
      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_repositories], 10.minutes

      def handle_event(event)
        repo = ::Search::Zoekt::Repository.find_by_id(event.data[:zoekt_repository_id])
        return if repo.nil?

        sql = "retries_left = retries_left - 1," \
          "state = CASE retries_left WHEN 1 THEN #{::Search::Zoekt::Repository.states[:failed]} " \
          "ELSE #{::Search::Zoekt::Repository.states[:pending]} END"
        ::Search::Zoekt::Repository.id_in(repo.id).update_all(sql)
        return unless repo.reset.failed?

        logger.info(build_structured_payload(message: 'Repository moved to failed', failed_repo_id: repo.id))
      end
    end
  end
end
