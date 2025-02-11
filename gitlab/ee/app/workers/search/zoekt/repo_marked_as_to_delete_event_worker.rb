# frozen_string_literal: true

module Search
  module Zoekt
    class RepoMarkedAsToDeleteEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_repositories, :zoekt_tasks], 10.minutes

      BATCH_SIZE = 500

      def handle_event(_event)
        Repository.should_be_deleted.limit(BATCH_SIZE).create_bulk_tasks(task_type: :delete_repo)
      end
    end
  end
end
