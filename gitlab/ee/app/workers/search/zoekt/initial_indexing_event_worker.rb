# frozen_string_literal: true

module Search
  module Zoekt
    class InitialIndexingEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_repositories], 10.minutes

      BATCH_SIZE = 1_000
      INSERT_LIMIT = 10_000

      # Create the pending zoekt_repositories and move the index to initializing
      def handle_event(event)
        index = find_index(event.data[:index_id])
        return if index.nil? || !index.pending?

        namespace = find_namespace(index.namespace_id)
        return if namespace.nil?

        index.initializing! if create_repositories(namespace: namespace, index: index)
      end

      private

      def find_index(index_id)
        Index.find_by_id(index_id)
      end

      def find_namespace(namespace_id)
        ::Namespace.find_by_id(namespace_id)
      end

      def create_repositories(namespace:, index:)
        if index.metadata['project_namespace_id_from'].present?
          return create_repositories_for_project_range(namespace: namespace, index: index)
        end

        create_repositories_with_scope(namespace: namespace, index: index)
      end

      def create_repositories_for_project_range(namespace:, index:)
        range_ids = determine_project_namespaces_id_range(index)
        create_repositories_with_scope(namespace: namespace, index: index) { |scope| scope.id_in(range_ids) }
      end

      def create_repositories_with_scope(namespace:, index:)
        number_of_inserts = 0
        fully_inserted = true

        project_namespaces = ::Namespace.by_root_id(namespace.id).project_namespaces
        project_namespaces = yield(project_namespaces) if block_given?
        project_namespaces.each_batch(of: BATCH_SIZE) do |project_namespaces_batch|
          scope = ::Project.by_project_namespace(project_namespaces_batch.select(:id))

          project_ids = scope.without_zoekt_repositories.pluck_primary_key
          next if project_ids.empty?

          result = insert_repositories(index: index, project_ids: project_ids)
          number_of_inserts += result.count

          if number_of_inserts >= INSERT_LIMIT
            fully_inserted = false
            break
          end
        end

        fully_inserted
      end

      def determine_project_namespaces_id_range(index)
        return (index.metadata['project_namespace_id_from']..) if index.metadata['project_namespace_id_to'].blank?

        index.metadata['project_namespace_id_from']..index.metadata['project_namespace_id_to']
      end

      def insert_repositories(index:, project_ids:)
        data = project_ids.map do |p_id|
          { zoekt_index_id: index.id, project_id: p_id, project_identifier: p_id }
        end
        Repository.insert_all(data)
      end
    end
  end
end
