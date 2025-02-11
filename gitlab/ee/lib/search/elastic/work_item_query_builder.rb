# frozen_string_literal: true

module Search
  module Elastic
    class WorkItemQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      DOC_TYPE = 'work_item'
      # iid field can be added here as lenient option will pardon format errors, like integer out of range.
      FIELDS = %w[iid^50 title^2 description].freeze
      THRESHOLD_FOR_GENERATING_EMBEDDING = 10

      def build
        options[:vectors_supported] = vectors_supported
        options[:fields] = fields

        query_hash = if hybrid_work_item_search?
                       ::Search::Elastic::Queries.by_knn(query: query, options: options)
                     else
                       build_query_hash(query: query, options: options)
                     end

        query_hash = get_authorization_filter(query_hash: query_hash, options: options)
        query_hash = get_confidentiality_filter(query_hash: query_hash, options: options)

        query_hash = ::Search::Elastic::Filters.by_state(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_not_hidden(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_label_ids(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_work_item_type_ids(query_hash: query_hash, options: options)

        if hybrid_work_item_search?
          query_hash = ::Search::Elastic::Filters.by_knn(query_hash: query_hash, options: options)
        end

        return ::Search::Elastic::Aggregations.by_label_ids(query_hash: query_hash) if options[:aggregation]

        query_hash = ::Search::Elastic::Formats.source_fields(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.page(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.size(query_hash: query_hash, options: options)

        ::Search::Elastic::Sorts.sort_by(query_hash: query_hash, options: options)
      end

      private

      def vectors_supported
        return false unless hybrid_work_item_search?
        return :elasticsearch if helper.vectors_supported?(:elasticsearch)
        return :opensearch if helper.vectors_supported?(:opensearch)

        false
      end

      def fields
        return options[:fields] if options[:fields].presence

        return FIELDS unless Feature.enabled?(:advanced_search_work_item_uses_note_fields, options[:current_user])

        FIELDS + %w[notes notes_internal]
      end

      def get_authorization_filter(query_hash:, options:)
        if options[:group_level_authorization]
          return ::Search::Elastic::Filters.by_group_level_authorization(query_hash: query_hash, options: options)
        end

        ::Search::Elastic::Filters.by_search_level_and_membership(query_hash: query_hash, options: options)
      end

      def get_confidentiality_filter(query_hash:, options:)
        if options[:group_level_confidentiality]
          return ::Search::Elastic::Filters.by_group_level_confidentiality(query_hash: query_hash,
            options: options)
        end

        ::Search::Elastic::Filters.by_project_confidentiality(query_hash: query_hash,
          options: options)
      end

      # rubocop: disable Gitlab/FeatureFlagWithoutActor -- global flags
      def hybrid_work_item_search?
        return false if iid_query?
        return false if short_query?
        return false unless Feature.enabled?(:ai_global_switch, type: :ops)
        return false unless Gitlab::Saas.feature_available?(:ai_vertex_embeddings)

        project = Project.find_by_id(options[:project_ids])
        user = options[:current_user]

        return false unless project && user
        return false unless Feature.enabled?(:search_work_items_hybrid_search, user)

        Feature.enabled?(:elasticsearch_work_item_embedding, project, type: :ops) &&
          user.any_group_with_ai_available?
      end
      strong_memoize_attr :hybrid_work_item_search?
      # rubocop: enable Gitlab/FeatureFlagWithoutActor

      override :extra_options
      def extra_options
        {
          doc_type: DOC_TYPE,
          features: 'issues',
          authorization_use_traversal_ids: true,
          project_visibility_level_field: :project_visibility_level,
          embedding_field: :embedding_0
        }
      end

      def helper
        @helper ||= Gitlab::Elastic::Helper.default
      end

      def short_query?
        query.size < THRESHOLD_FOR_GENERATING_EMBEDDING
      end

      def iid_query?
        query =~ /#(\d+)\z/
      end

      def build_query_hash(query:, options:)
        if iid_query?
          query =~ /#(\d+)\z/ # To get the match correctly
          ::Search::Elastic::Queries.by_iid(iid: Regexp.last_match(1), doc_type: DOC_TYPE)
        else
          ::Search::Elastic::Queries.by_full_text(query: query, options: options)
        end
      end
    end
  end
end
