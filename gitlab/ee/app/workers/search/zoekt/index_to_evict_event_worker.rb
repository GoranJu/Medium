# frozen_string_literal: true

module Search
  module Zoekt
    class IndexToEvictEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_indices, :zoekt_replicas], 10.minutes

      BATCH_SIZE = 1000

      def handle_event(_event)
        indices = Search::Zoekt::Index.pending_eviction.ordered.limit(BATCH_SIZE)
        return unless indices.exists?

        log_metadata = {}

        ApplicationRecord.transaction do
          deleted_count = Search::Zoekt::Replica.id_in(indices.select(:zoekt_replica_id)).delete_all
          updated_count = indices.update_all(state: :evicted)

          log_metadata[:replicas_deleted_count] = deleted_count
          log_metadata[:indices_updated_count] = updated_count
        end

        log_hash_metadata_on_done(log_metadata)
      end
    end
  end
end
