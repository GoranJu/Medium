# frozen_string_literal: true

module Search
  module Elastic
    module IssuesSearch
      extend ActiveSupport::Concern

      include ::Elastic::ApplicationVersionedSearch

      EMBEDDING_TRACKED_FIELDS = %i[title description].freeze

      included do
        extend ::Gitlab::Utils::Override

        override :maintain_elasticsearch_create
        def maintain_elasticsearch_create
          ::Elastic::ProcessBookkeepingService.track!(*get_indexing_data)

          track_embedding! if track_embedding?
        end

        override :maintain_elasticsearch_update
        def maintain_elasticsearch_update(updated_attributes: previous_changes.keys)
          ::Elastic::ProcessBookkeepingService.track!(*get_indexing_data)
          super unless indexing_issue_of_epic_type?

          track_embedding! if (updated_attributes.map(&:to_sym) & EMBEDDING_TRACKED_FIELDS).any? && track_embedding?
        end

        override :maintain_elasticsearch_destroy
        def maintain_elasticsearch_destroy
          ::Elastic::ProcessBookkeepingService.track!(*get_indexing_data)
        end

        private

        # rubocop: disable Gitlab/FeatureFlagWithoutActor -- global flags
        def track_embedding?
          instance_of?(WorkItem) &&
            project&.public? &&
            Feature.enabled?(:ai_global_switch, type: :ops) &&
            Feature.enabled?(:elasticsearch_work_item_embedding, project, type: :ops) &&
            Gitlab::Saas.feature_available?(:ai_vertex_embeddings) &&
            (work_item_embeddings_elastic? || work_item_embeddings_opensearch?)
        end
        # rubocop: enable Gitlab/FeatureFlagWithoutActor

        def track_embedding!
          ::Search::Elastic::ProcessEmbeddingBookkeepingService.track_embedding!(self)
        end
      end

      private

      def indexing_issue_of_epic_type?
        project.nil?
      end

      def get_indexing_data
        indexing_data = []
        case self
        when WorkItem
          indexing_data << self

          unless indexing_issue_of_epic_type?
            indexing_data << Search::Elastic::References::Legacy.instantiate_from_array([Issue, id, es_id,
              "project_#{project.id}"])
          end
        when Issue
          indexing_data << Search::Elastic::References::WorkItem.new(id, "group_#{namespace.root_ancestor.id}")
          indexing_data << self unless indexing_issue_of_epic_type?
        end
        indexing_data.compact
      end

      def work_item_embeddings_elastic?
        Gitlab::Elastic::Helper.default.vectors_supported?(:elasticsearch)
      end

      def work_item_embeddings_opensearch?
        Gitlab::Elastic::Helper.default.vectors_supported?(:opensearch)
      end
    end
  end
end
