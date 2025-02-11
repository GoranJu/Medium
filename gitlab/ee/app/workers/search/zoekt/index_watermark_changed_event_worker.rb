# frozen_string_literal: true

module Search
  module Zoekt
    class IndexWatermarkChangedEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_indices], 10.minutes

      BATCH_SIZE = 1000

      def handle_event(_event)
        indices = Search::Zoekt::Index.with_mismatched_watermark_levels
          .or(Search::Zoekt::Index.negative_reserved_storage_bytes).limit(BATCH_SIZE)

        return unless indices.exists?

        updated_count = 0
        indices.find_each do |idx|
          idx.update_reserved_storage_bytes!

          updated_count += 1
        rescue ActiveRecord::ActiveRecordError
          # no-op, record will be processed on next worker run
        end

        log_extra_metadata_on_done(:indices_updated_count, updated_count)
      end
    end
  end
end
