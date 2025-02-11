# frozen_string_literal: true

module Search
  module Zoekt
    class NamespaceIndexerWorker
      include ApplicationWorker
      include Search::Worker
      prepend ::Geo::SkipSecondary

      # Must be always otherwise we risk race condition where it does not think that indexing is enabled yet for the
      # namespace.
      data_consistency :always
      idempotent!
      pause_control :zoekt

      def perform(namespace_id, operation, node_id = nil)
        return unless ::Gitlab::CurrentSettings.zoekt_indexing_enabled?

        namespace = Namespace.find(namespace_id)

        # Symbols convert to string when queuing in Sidekiq
        case operation.to_sym
        when :index
          index_projects(namespace)
        when :delete
          remove_projects(namespace, node_id: node_id)
        end
      end

      private

      def index_projects(namespace)
        return unless namespace.use_zoekt?

        namespace.all_projects.find_each { |project| ::Search::Zoekt.index_async(project.id) }
      end

      def remove_projects(namespace, node_id:)
        namespace.all_projects.find_each do |project|
          ::Search::Zoekt.delete_async(project.id, root_namespace_id: project.root_namespace&.id, node_id: node_id)
        end
      end
    end
  end
end
