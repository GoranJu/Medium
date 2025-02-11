# frozen_string_literal: true

module EE
  module Search
    module ProjectService
      extend ::Gitlab::Utils::Override
      include ::Search::AdvancedAndZoektSearchable

      SCOPES_THAT_SUPPORT_BRANCHES = %w[wiki_blobs commits blobs].freeze

      override :zoekt_filters
      def zoekt_filters
        super.merge(include_archived: true, include_forked: true)
      end

      override :search_type
      def search_type
        use_default_branch? ? super : 'basic'
      end

      def elasticsearch_results
        search = params[:search]
        order_by = params[:order_by]
        sort = params[:sort]

        if project.is_a?(Array)
          project_id_root_ancestor_id_hash = project.to_h { |p| [p.id, p.root_ancestor.id] }
          project_ids = project_id_root_ancestor_id_hash.keys
          root_ancestor_ids = project_id_root_ancestor_id_hash.values
          ::Gitlab::Elastic::SearchResults.new(
            current_user,
            search,
            project_ids,
            root_ancestor_ids: root_ancestor_ids,
            public_and_internal_projects: false,
            order_by: order_by,
            sort: sort,
            filters: filters
          )
        else
          ::Gitlab::Elastic::ProjectSearchResults.new(
            current_user,
            search,
            project: project,
            root_ancestor_ids: [project.root_ancestor.id],
            repository_ref: repository_ref,
            order_by: order_by,
            sort: sort,
            filters: filters
          )
        end
      end

      def repository_ref
        params[:repository_ref]
      end

      def use_default_branch?
        return true if repository_ref.blank?
        return true unless SCOPES_THAT_SUPPORT_BRANCHES.include?(scope)

        project.root_ref?(repository_ref)
      end

      override :elasticsearchable_scope
      def elasticsearchable_scope
        project unless global_elasticsearchable_scope?
      end

      override :zoekt_searchable_scope
      def zoekt_searchable_scope
        project
      end

      override :zoekt_projects
      def zoekt_projects
        @zoekt_projects ||= ::Project.id_in(project)
      end

      override :zoekt_nodes
      def zoekt_nodes
        @zoekt_nodes ||= ::Search::Zoekt::Node.searchable_for_project(zoekt_searchable_scope)
      end
    end
  end
end
