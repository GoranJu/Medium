# frozen_string_literal: true

module EE
  module Search
    module GroupService
      extend ::Gitlab::Utils::Override
      include ::Search::AdvancedAndZoektSearchable

      override :elasticsearchable_scope
      def elasticsearchable_scope
        group unless global_elasticsearchable_scope?
      end

      override :zoekt_searchable_scope
      def zoekt_searchable_scope
        group
      end

      override :zoekt_node_id
      def zoekt_node_id; end

      override :zoekt_filters
      def zoekt_filters
        super.merge(include_archived: params[:include_archived], include_forked: params[:include_forked])
      end

      override :elastic_global
      def elastic_global
        false
      end

      override :elastic_projects
      def elastic_projects
        @elastic_projects ||= projects.pluck_primary_key
      end

      def elasticsearch_results
        ::Gitlab::Elastic::GroupSearchResults.new(
          current_user,
          params[:search],
          elastic_projects,
          group: group,
          public_and_internal_projects: elastic_global,
          order_by: params[:order_by],
          sort: params[:sort],
          filters: filters
        )
      end

      override :allowed_scopes
      def allowed_scopes
        strong_memoize(:ee_group_allowed_scopes) do
          scopes = super

          if use_elasticsearch?
            scopes -= %w[epics] unless group.licensed_feature_available?(:epics)
          else
            scopes += %w[epics] # In basic search we have epics enabled for groups
          end

          scopes.uniq
        end
      end
    end
  end
end
