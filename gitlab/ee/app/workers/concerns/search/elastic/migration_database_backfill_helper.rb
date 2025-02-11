# frozen_string_literal: true

module Search
  module Elastic
    module MigrationDatabaseBackfillHelper
      DEFAULT_LIMIT_PER_ITERATION = 1_000

      def migrate
        if completed?
          log 'Migration is completed'

          return
        end

        backfill_documents
      end

      def completed?
        completed = documents_after_current_id.empty?

        unless completed
          maximum_id = documents_after_current_id.maximum(:id).to_i
          documents_remaining_approximate = maximum_id - current_id

          set_migration_state(maximum_id: maximum_id, documents_remaining_approximate: documents_remaining_approximate)

          log 'Migration is not finished', maximum_id: maximum_id, current_id: current_id,
            documents_remaining_approximate: documents_remaining_approximate
        end

        completed
      end

      def document_type
        return self.class::DOCUMENT_TYPE if self.class.const_defined?(:DOCUMENT_TYPE)

        raise NotImplementedError
      end

      def respect_limited_indexing?
        raise NotImplementedError
      end

      def item_to_preload
        raise NotImplementedError
      end

      private

      def limit_indexing?
        respect_limited_indexing? && ::Gitlab::CurrentSettings.elasticsearch_limit_indexing?
      end

      def limit_per_iteration
        DEFAULT_LIMIT_PER_ITERATION
      end

      def number_of_iterations_per_run
        (batch_size / limit_per_iteration.to_f).ceil
      end

      def current_id
        migration_state[:current_id].to_i
      end

      def documents_after_current_id
        document_type.where("id > ?", current_id).order(:id) # rubocop:disable CodeReuse/ActiveRecord -- we need to select only unprocessed ids
      end

      def backfill_documents
        [].tap do |documents|
          number_of_iterations_per_run.times do
            documents = documents_after_current_id.limit(limit_per_iteration)

            if limit_indexing?
              documents = documents.preload(item_to_preload) # rubocop: disable CodeReuse/ActiveRecord -- Avoid N+1
            end

            documents = documents.to_a
            break if documents.blank?

            max_id = documents.maximum(:id).to_i

            documents.select!(&:maintaining_elasticsearch?) if limit_indexing?

            ::Elastic::ProcessInitialBookkeepingService.track!(*documents)
            set_migration_state(current_id: max_id)
          end
        end
      end
    end
  end
end
