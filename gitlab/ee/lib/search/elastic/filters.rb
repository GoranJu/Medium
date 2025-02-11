# frozen_string_literal: true

module Search
  module Elastic
    module Filters
      ALLOWED_SEARCH_LEVELS = %i[global group project].freeze

      class << self
        include ::Elastic::Latest::QueryContext::Aware

        def by_search_level_and_membership(query_hash:, options:)
          raise ArgumentError, 'search_level is required' unless options.key?(:search_level)

          unless ALLOWED_SEARCH_LEVELS.include?(options[:search_level].to_sym)
            raise ArgumentError, 'search_level invalid'
          end

          query_hash = search_level_filter(query_hash: query_hash, options: options)

          membership_filter(query_hash: query_hash, options: options)
        end

        def by_source_branch(query_hash:, options:)
          source_branch = options[:source_branch]
          not_source_branch = options[:not_source_branch]

          return query_hash unless source_branch || not_source_branch

          context.name(:filters) do
            should = []
            if source_branch
              should << { term: { source_branch: { _name: context.name(:source_branch), value: source_branch } } }
            end

            if not_source_branch
              should << {
                bool: {
                  must_not: {
                    term: { source_branch: { _name: context.name(:not_source_branch), value: not_source_branch } }
                  }
                }
              }
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: { should: should, minimum_should_match: 1 } }
            end
          end
        end

        def by_target_branch(query_hash:, options:)
          target_branch = options[:target_branch]
          not_target_branch = options[:not_target_branch]

          return query_hash unless target_branch || not_target_branch

          context.name(:filters) do
            should = []
            if target_branch
              should << { term: { target_branch: { _name: context.name(:target_branch), value: target_branch } } }
            end

            if not_target_branch
              should << {
                bool: {
                  must_not: {
                    term: { target_branch: { _name: context.name(:not_target_branch), value: not_target_branch } }
                  }
                }
              }
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: { should: should, minimum_should_match: 1 } }
            end
          end
        end

        def by_author(query_hash:, options:)
          author_username = options[:author_username]
          not_author_username = options[:not_author_username]

          return query_hash unless author_username || not_author_username

          included_user = User.find_by_username(author_username)
          excluded_user = User.find_by_username(not_author_username)

          return query_hash unless included_user || excluded_user

          context.name(:filters) do
            should = []
            if included_user
              should << { term: { author_id: { _name: context.name(:author), value: included_user.id } } }
            end

            if excluded_user
              should << {
                bool: {
                  must_not: {
                    term: { author_id: { _name: context.name(:not_author), value: excluded_user.id } }
                  }
                }
              }
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: { should: should, minimum_should_match: 1 } }
            end
          end
        end

        def by_work_item_type_ids(query_hash:, options:)
          work_item_type_ids = options[:work_item_type_ids]
          not_work_item_type_ids = options[:not_work_item_type_ids]

          return query_hash unless work_item_type_ids || not_work_item_type_ids

          context.name(:filters) do
            if work_item_type_ids
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must: {
                      bool: {
                        should: [
                          {
                            terms: {
                              _name: context.name(:work_item_type_ids),
                              work_item_type_id: work_item_type_ids
                            }
                          },
                          {
                            terms: {
                              _name: context.name(:correct_work_item_type_ids),
                              correct_work_item_type_id: work_item_type_ids
                            }
                          }
                        ],
                        minimum_should_match: 1
                      }
                    }
                  }
                }
              end
            end

            if not_work_item_type_ids
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must_not: {
                      bool: {
                        should: [
                          {
                            terms: {
                              _name: context.name(:not_work_item_type_ids),
                              work_item_type_id: not_work_item_type_ids
                            }
                          },
                          {
                            terms: {
                              _name: context.name(:not_correct_work_item_type_ids),
                              correct_work_item_type_id: not_work_item_type_ids
                            }
                          }
                        ],
                        minimum_should_match: 1
                      }
                    }
                  }
                }
              end
            end
          end
          query_hash
        end

        def by_not_hidden(query_hash:, options:)
          user = options[:current_user]
          return query_hash if user&.can_admin_all_resources?

          context.name(:filters) do
            add_filter(query_hash, :query, :bool, :filter) do
              { term: { hidden: { _name: context.name(:not_hidden), value: false } } }
            end
          end
        end

        def by_state(query_hash:, options:)
          state = options[:state]
          return query_hash if state.blank? || state == 'all'
          return query_hash unless API::Helpers::SearchHelpers.search_states.include?(state)

          context.name(:filters) do
            add_filter(query_hash, :query, :bool, :filter) do
              { match: { state: { _name: context.name(:state), query: state } } }
            end
          end
        end

        def by_archived(query_hash:, options:)
          raise ArgumentError, 'search_level is a required option' unless options.key?(:search_level)

          include_archived = !!options[:include_archived]
          search_level = options[:search_level].to_sym
          return query_hash if search_level == :project
          return query_hash if include_archived

          context.name(:filters) do
            archived_false_filter = { bool: { filter: { term: { archived: { value: false } } } } }
            archived_missing_filter = { bool: { must_not: { exists: { field: 'archived' } } } }
            exclude_archived_filter = { bool: { _name: context.name(:non_archived),
                                                should: [archived_false_filter, archived_missing_filter] } }

            add_filter(query_hash, :query, :bool, :filter) do
              exclude_archived_filter
            end
          end
        end

        def by_label_ids(query_hash:, options:)
          return query_hash if options[:count_only] || options[:aggregation]

          return query_hash unless [options[:label_name]].flatten.any?

          label_names_hash = find_labels_by_name([options[:label_name]].flatten, options)
          return query_hash unless label_names_hash.any?

          must_query = { must: [] }
          context.name(:filters) do
            label_names_hash.each_value do |label_ids|
              must_query[:must] << {
                terms: {
                  _name: context.name(:label_ids),
                  label_ids: label_ids
                }
              }
            end
          end

          add_filter(query_hash, :query, :bool, :filter) do
            { bool: must_query }
          end
        end

        def by_knn(query_hash:, options:)
          return query_hash unless options[:embeddings]
          return query_hash unless options[:vectors_supported] == :elasticsearch

          filters = query_hash.dig(:query, :bool, :filter)

          query_hash.deep_merge(knn: { filter: filters })
        end

        def by_group_level_confidentiality(query_hash:, options:)
          user = options[:current_user]
          query_hash = search_level_filter(query_hash: query_hash, options: options)
          return query_hash if user.nil? || user&.can_read_all_resources?

          confidential_group_ids = group_ids_user_has_min_access_as(
            access_level: ::Gitlab::Access::REPORTER, user: options[:current_user], group_ids: options[:group_ids]
          )

          context.name(:filters) do
            should = [{ term: { confidential: { value: false, _name: context.name(:non_confidential, :groups) } } }]

            unless confidential_group_ids.empty?
              should << {
                bool: {
                  must: [
                    { term: { confidential: { value: true, _name: context.name(:confidential, :groups) } } },
                    { terms: { namespace_id: confidential_group_ids,
                               _name: context.name(:confidential, :groups, "can_read_confidential_work_items") } }
                  ]
                }
              }
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: { should: should } }
            end
          end
        end

        def by_group_level_authorization(query_hash:, options:)
          user = options[:current_user]
          query_hash = search_level_filter(query_hash: query_hash, options: options)
          return query_hash if user&.can_read_all_resources?

          context.name(:filters) do
            add_filter(query_hash, :query, :bool, :filter) do
              visibility_filters = Search::Elastic::BoolExpr.new
              visibility_filters.minimum_should_match = 1
              add_filter(visibility_filters, :should) do
                { bool: { filter: [
                  { term: { namespace_visibility_level: { value: ::Gitlab::VisibilityLevel::PUBLIC,
                                                          _name: context.name(:namespace_visibility_level,
                                                            :public) } } }
                ] } }
              end

              if user && !user.external?
                add_filter(visibility_filters, :should) do
                  { bool: { filter: [
                    { term: { namespace_visibility_level: { value: ::Gitlab::VisibilityLevel::INTERNAL,
                                                            _name: context.name(:namespace_visibility_level,
                                                              :internal) } } }
                  ] } }
                end
                authorized_group_ids = group_ids_user_has_min_access_as(access_level: ::Gitlab::Access::GUEST,
                  user: user, group_ids: options[:group_ids])

                unless authorized_group_ids.empty?
                  add_filter(visibility_filters, :should) do
                    { bool: { filter: [
                      { term: { namespace_visibility_level: { value: ::Gitlab::VisibilityLevel::PRIVATE,
                                                              _name: context.name(:namespace_visibility_level,
                                                                :private) } } },
                      { terms: { namespace_id: authorized_group_ids } }

                    ] } }
                  end
                end

              end

              { bool: visibility_filters.to_h }
            end
          end
        end

        def by_project_confidentiality(query_hash:, options:)
          confidential = options[:confidential]
          user = options[:current_user]
          project_ids = options[:project_ids]

          context.name(:filters) do
            if [true, false].include?(confidential)
              add_filter(query_hash, :query, :bool, :filter) do
                { term: { confidential: confidential } }
              end
            end

            next query_hash if user&.can_read_all_resources?

            scoped_project_ids = scoped_project_ids(user, project_ids)
            authorized_project_ids = authorized_project_ids(user, scoped_project_ids)

            # we can shortcut the filter if the user is authorized to see
            # all the projects for which this query is scoped on
            if !(scoped_project_ids == :any || scoped_project_ids.empty?) &&
                (authorized_project_ids.to_set == scoped_project_ids.to_set)
              next query_hash
            end

            non_confidential_filter = {
              term: { confidential: { _name: context.name(:non_confidential), value: false } }
            }

            filter = if user
                       confidential_filter = {
                         bool: {
                           must: [
                             { term: { confidential: { _name: context.name(:confidential), value: true } } },
                             {
                               bool: {
                                 should: [
                                   { term:
                                    { author_id: {
                                      _name: context.name(:confidential, :as_author),
                                      value: user.id
                                    } } },
                                   { term:
                                    { assignee_id: {
                                      _name: context.name(:confidential, :as_assignee),
                                      value: user.id
                                    } } },
                                   { terms: { _name: context.name(:confidential, :project, :membership, :id),
                                              project_id: authorized_project_ids } }
                                 ]
                               }
                             }
                           ]
                         }
                       }

                       {
                         bool: {
                           should: [
                             non_confidential_filter,
                             confidential_filter
                           ]
                         }
                       }
                     else
                       non_confidential_filter
                     end

            add_filter(query_hash, :query, :bool, :filter) do
              filter
            end
          end
        end

        # deprecated - use by_search_level_and_membership
        def by_project_authorization(query_hash:, options:)
          user = options[:current_user]
          project_ids = options[:project_ids]
          group_ids = options[:group_ids]
          use_traversal_ids = options.fetch(:authorization_use_traversal_ids)

          context.name(:filters) do
            if project_ids == :any || group_ids.blank? || !use_traversal_ids
              next project_ids_filter(query_hash, options)
            end

            namespaces = Namespace.find(authorized_namespace_ids(user, group_ids))

            next project_ids_filter(query_hash, options) if namespaces.blank?

            traversal_ids_filter(query_hash, namespaces, options)
          end
        end

        def by_type(query_hash:, options:)
          raise ArgumentError, 'by_type filter requires doc_type option' unless options.key?(:doc_type)

          doc_type = options[:doc_type]
          context.name(:filters) do
            add_filter(query_hash, :query, :bool, :filter) do
              {
                term: {
                  type: {
                    _name: context.name(:doc, :is_a, doc_type),
                    value: doc_type
                  }
                }
              }
            end
          end
        end

        private

        # This is a helper method that we are using to add filter conditions
        # in this method we are skipping all blank hashes and we can use it for adding nested filter conditions.
        # `path` is a sequence of key objects (Hash#dig syntax). The value by that path should be an array.
        def add_filter(query_hash, *path)
          filter_result = yield

          return query_hash if filter_result.blank?

          query_hash.dig(*path) << filter_result
          query_hash
        end

        def group_ids_user_has_min_access_as(access_level:, user:, group_ids:)
          finder_params = { min_access_level: access_level }
          if group_ids.present?
            finder_params[:filter_group_ids] =
              Group.id_in(group_ids.uniq).map(&:self_and_descendants_ids).uniq
          end

          ::GroupsFinder.new(user, finder_params).execute.pluck("#{Group.table_name}.#{Group.primary_key}") # rubocop:disable CodeReuse/ActiveRecord -- we need pluck only the ids from the finder
        end

        def scoped_project_ids(current_user, project_ids)
          return :any if project_ids == :any

          project_ids ||= []

          # When reading cross project is not allowed, only allow searching a
          # a single project, so the `:read_*` ability is only checked once.
          return [] if !Ability.allowed?(current_user, :read_cross_project) && project_ids.size > 1

          project_ids
        end

        def project_ids_for_user(user, options)
          return [] unless user

          search_level = options.fetch(:search_level).to_sym
          authorized_projects = ::Search::ProjectsFinder.new(user: user).execute

          projects = case search_level
                     when :global
                       authorized_projects
                     when :group
                       namespace_ids = options[:group_ids]
                       projects = Project.in_namespace(namespace_ids)
                       if !projects.id_not_in(authorized_projects).exists?
                         projects
                       else
                         Project.from_union([
                           authorized_projects.in_namespace(namespace_ids),
                           authorized_projects.by_any_overlap_with_traversal_ids(namespace_ids)
                         ])
                       end
                     when :project
                       project_ids = options[:project_ids]
                       projects = Project.id_in(project_ids)
                       if !projects.id_not_in(authorized_projects).exists?
                         projects
                       else
                         authorized_projects.id_in(project_ids)
                       end
                     end

          features = Array.wrap(options[:features])
          return projects.pluck_primary_key unless features.present?

          project_ids_for_features(projects, user, features)
        end

        def traversal_ids_for_user(user, options)
          return [] unless user

          search_level = options.fetch(:search_level).to_sym
          features = Array.wrap(options[:features])

          allowed_traversal_ids = case search_level
                                  when :global
                                    authorized_traversal_ids_for_global(user, features)
                                  when :group
                                    authorized_traversal_ids_for_groups(user, options[:group_ids], features)
                                  when :project
                                    authorized_traversal_ids_for_projects(user, options[:project_ids], features)
                                  end

          allowed_traversal_ids.map { |id| "#{id.join('-')}-" }
        end

        def authorized_traversal_ids_for_global(user, features)
          authorized_groups = ::Search::GroupsFinder.new(user: user, params: { features: features }).execute

          ::Namespaces::Traversal::TrieNode.build(authorized_groups.map(&:traversal_ids)).to_a
        end

        def authorized_traversal_ids_for_groups(user, namespace_ids, features)
          authorized_groups = ::Search::GroupsFinder.new(user: user, params: { features: features }).execute
          namespaces = Namespace.id_in(namespace_ids)

          return namespaces.map(&:traversal_ids) unless namespaces.id_not_in(authorized_groups).exists?

          authorized_trie = ::Namespaces::Traversal::TrieNode.build(authorized_groups.map(&:traversal_ids))

          [].tap do |allowed_traversal_ids|
            namespaces.map do |namespace|
              traversal_ids = namespace.traversal_ids
              if authorized_trie.covered?(traversal_ids)
                allowed_traversal_ids << traversal_ids
                next
              end

              allowed_traversal_ids.concat(authorized_trie.prefix_search(traversal_ids))
            end
          end
        end

        def authorized_traversal_ids_for_projects(user, project_ids, features)
          authorized_groups = ::Search::GroupsFinder.new(user: user, params: { features: features }).execute
          namespace_ids = Project.id_in(project_ids).select(:namespace_id)
          namespaces = Namespace.id_in(namespace_ids)

          return namespaces.map(&:traversal_ids) unless namespaces.id_not_in(authorized_groups).exists?

          authorized_trie = ::Namespaces::Traversal::TrieNode.build(authorized_groups.map(&:traversal_ids))

          namespaces.map(&:traversal_ids).select { |s| authorized_trie.covered?(s) }
        end

        def visibility_level_for_user(user, visibility_level_field)
          if user && !user.external?
            { terms: {
              _name: context.name(visibility_level_field, :public_and_internal),
              "#{visibility_level_field}": [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL]
            } }
          else
            { terms: {
              _name: context.name(visibility_level_field, :public),
              "#{visibility_level_field}": [::Gitlab::VisibilityLevel::PUBLIC]
            } }
          end
        end

        def authorized_project_ids(current_user, scoped_project_ids)
          return [] unless current_user

          authorized_project_ids = current_user.authorized_projects(Gitlab::Access::REPORTER).pluck_primary_key.to_set

          # if the current search is limited to a subset of projects, we should do
          # confidentiality check for these projects.
          authorized_project_ids &= scoped_project_ids.to_set unless scoped_project_ids == :any

          authorized_project_ids.to_a
        end

        def authorized_namespace_ids(user, group_ids)
          return [] unless user && group_ids.present?

          authorized_ids = user.authorized_groups.pluck_primary_key.to_set
          authorized_ids.intersection(group_ids.to_set).to_a
        end

        # Builds an elasticsearch query that will select child documents from a
        # set of projects, taking user access rules into account.
        def project_ids_filter(query_hash, options)
          context.name(:project) do
            project_query = project_ids_query(options)

            add_filter(query_hash, :query, :bool, :filter) do
              # Some models have denormalized project permissions into the
              # document so that we do not need to use joins
              if options[:no_join_project]
                project_query[:_name] = context.name
                {
                  bool: project_query
                }
              else
                {
                  has_parent: {
                    _name: "#{context.name}:parent",
                    parent_type: "project",
                    query: {
                      bool: project_query
                    }
                  }
                }
              end
            end
          end
        end

        # Builds an elasticsearch query that will select projects the user is
        # granted access to.
        #
        # If a project feature(s) is specified, it indicates interest in child
        # documents gated by that project feature - e.g., "issues". The feature's
        # visibility level must be taken into account.
        def project_ids_query(options)
          user = options[:current_user]
          project_ids = options[:project_ids]
          public_and_internal_projects = options[:public_and_internal_projects]
          features = options[:features]
          no_join_project = options[:no_join_project]
          project_id_field = options[:project_id_field]
          project_visibility_level_field = options.fetch(:project_visibility_level_field, :visibility_level)

          scoped_project_ids = scoped_project_ids(user, project_ids)

          # At least one condition must be present, so pick no projects for
          # anonymous users.
          # Pick private, internal and public projects the user is a member of.
          # Pick all private projects for admins & auditors.
          conditions = pick_projects_by_membership(
            scoped_project_ids,
            user, no_join_project,
            features: features,
            project_id_field: project_id_field,
            project_visibility_level_field: project_visibility_level_field
          )

          if public_and_internal_projects
            context.name(:visibility) do
              # Skip internal projects for anonymous and external users.
              # Others are given access to all internal projects.
              #
              # Admins & auditors get access to internal projects even
              # if the feature is private.
              if user && !user.external?
                conditions += pick_projects_by_visibility(Project::INTERNAL, user, features,
                  project_visibility_level_field: project_visibility_level_field)
              end

              # All users, including anonymous, can access public projects.
              # Admins & auditors get access to public projects where the feature is
              # private.
              conditions += pick_projects_by_visibility(Project::PUBLIC, user, features,
                project_visibility_level_field: project_visibility_level_field)
            end
          end

          { should: conditions }
        end

        # Most users come with a list of projects they are members of, which may
        # be a mix of public, internal or private. Grant access to them all, as
        # long as the project feature is not disabled.
        #
        # Admins & auditors are given access to all private projects. Access to
        # internal or public projects where the project feature is private is not
        # granted here.
        def pick_projects_by_membership(
          project_ids, user, no_join_project, project_visibility_level_field:, features: nil, project_id_field: nil)
          # This method is used to construct a query on the join as well as query
          # on top level doc. When querying top level doc the project's ID is
          # used from project_id_field with the default value of `project_id`
          # When joining it is just `id`.
          id_field = if no_join_project
                       project_id_field || :project_id
                     else
                       :id
                     end

          if features.nil?
            if project_ids == :any
              return [{ term: { project_visibility_level_field => { _name: context.name(:any),
                                                                    value: Project::PRIVATE } } }]
            end

            return [{ terms: { _name: context.name(:membership, :id), id_field => project_ids } }]
          end

          Array(features).map do |feature|
            condition =
              if project_ids == :any
                { term: { project_visibility_level_field => { _name: context.name(:any), value: Project::PRIVATE } } }
              else
                {
                  terms: {
                    _name: context.name(:membership, :id),
                    id_field => filter_project_ids_by_feature(project_ids, user, feature)
                  }
                }
              end

            limit = {
              terms: {
                _name: context.name(feature, :enabled_or_private),
                "#{feature}_access_level" => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
              }
            }

            {
              bool: {
                filter: [condition, limit]
              }
            }
          end
        end

        # Grant access to projects of the specified visibility level to the user.
        #
        # If a project feature is specified, access is only granted if the feature
        # is enabled or, for admins & auditors, private.
        def pick_projects_by_visibility(visibility, user, features, project_visibility_level_field:)
          context.name(visibility) do
            condition = { term: { project_visibility_level_field => { _name: context.name, value: visibility } } }

            limit_by_feature(condition, features, include_members_only: user&.can_read_all_resources?)
          end
        end

        # If a project feature(s) is specified, access is dependent on its visibility
        # level being enabled (or private if `include_members_only: true`).
        #
        # This method is a no-op if no project feature is specified.
        # It accepts an array of features or a single feature, when an array is provided
        # it queries if any of the features is enabled.
        #
        # Always denies access to projects when the features are disabled - even to
        # admins & auditors - as stale child documents may be present.
        def limit_by_feature(condition, features, include_members_only:)
          return [condition] unless features

          features = Array(features)
          features.map do |feature|
            context.name(feature, :access_level) do
              limit =
                if include_members_only
                  {
                    terms: {
                      _name: context.name(:enabled_or_private),
                      "#{feature}_access_level" => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    }
                  }
                else
                  {
                    term: {
                      "#{feature}_access_level" => {
                        _name: context.name(:enabled),
                        value: ::ProjectFeature::ENABLED
                      }
                    }
                  }
                end

              {
                bool: {
                  _name: context.name,
                  filter: [condition, limit]
                }
              }
            end
          end
        end

        def traversal_ids_filter(query_hash, namespaces, options)
          namespace_ancestry = namespaces.map(&:elastic_namespace_ancestry)

          context.name(:reject_projects) do
            add_filter(query_hash, :query, :bool, :must_not) do
              rejected_project_filter(namespaces, options)
            end
          end

          traversal_ids_ancestry_filter(query_hash, namespace_ancestry, options)
        end

        # Useful when performing group searches by traversal_id to prevent
        # access to projects in the group hierarchy that the user does not have
        # permission to view.
        def rejected_project_filter(namespaces, options)
          current_user = options[:current_user]
          scoped_project_ids = scoped_project_ids(current_user, options[:project_ids])
          return {} if scoped_project_ids == :any

          project_ids = []
          Array.wrap(options[:features]).each do |feature|
            project_ids.concat(filter_project_ids_by_feature(scoped_project_ids, current_user, feature))
          end

          rejected_ids = namespaces.flat_map do |namespace|
            namespace.all_project_ids_except(project_ids).pluck_primary_key
          end

          {
            terms: {
              _name: context.name,
              "#{options[:project_id_field]}": rejected_ids
            }
          }
        end

        def traversal_ids_ancestry_filter(query_hash, namespace_ancestry, options)
          return {} unless options[:current_user] || namespace_ancestry.blank?

          context.name(:namespace) do
            add_filter(query_hash, :query, :bool, :filter) do
              {
                bool: {
                  should: ancestry_filter(namespace_ancestry,
                    traversal_id_field: options.fetch(:traversal_ids_prefix, :traversal_ids)),
                  minimum_should_match: 1
                }
              }
            end
          end
        end

        def ancestry_filter(namespace_ancestry, traversal_id_field:)
          context.name(:ancestry_filter) do
            namespace_ancestry.map do |namespace_ids|
              {
                prefix: {
                  "#{traversal_id_field}": {
                    _name: context.name(:descendants),
                    value: namespace_ids
                  }
                }
              }
            end
          end
        end

        def filter_project_ids_by_feature(project_ids, user, feature)
          Project
            .id_in(project_ids)
            .filter_by_feature_visibility(feature, user)
            .pluck_primary_key
        end

        def project_ids_for_features(projects, user, features)
          project_ids = projects.pluck_primary_key

          allowed_ids = []
          features.each do |feature|
            allowed_ids.concat(filter_project_ids_by_feature(project_ids, user, feature))
          end

          abilities = features.map { |feature| ability_to_access_feature(feature) }

          allowed_ids.concat(filter_project_ids_by_abilities(projects, user, abilities))
          allowed_ids.uniq
        end

        def filter_project_ids_by_abilities(projects, user, target_abilities)
          return [] if target_abilities.empty? || user.blank?

          actual_abilities = ::Authz::Project.new(user, scope: projects).permitted

          projects.filter_map do |project|
            project.id if (actual_abilities[project.id] || []).intersection(target_abilities).any?
          end
        end

        def ability_to_access_feature(feature)
          case feature&.to_sym
          when :repository
            :read_code
          end
        end

        def find_labels_by_name(names, options)
          raise ArgumentError, 'search_level is a required option' unless options.key?(:search_level)

          return [] if names.empty?

          search_level = options[:search_level].to_sym
          finder_params = { name: names }

          labels = case search_level
                   when :global
                     find_global_labels(finder_params)
                   when :group
                     find_group_labels(finder_params, options[:group_ids])
                   when :project
                     find_project_labels(finder_params, options[:group_ids], options[:project_ids])
                   else
                     raise ArgumentError, 'Invalid search_level option provided'
                   end

          group_labels_by_name(labels)
        end

        def find_global_labels(finder_params)
          LabelsFinder.new(nil, finder_params).execute(skip_authorization: true)
        end

        def find_group_labels(finder_params, group_ids)
          return find_global_labels(finder_params) if group_ids.blank?

          finder_params[:include_descendant_groups] = true
          finder_params[:include_ancestor_groups] = true

          group_ids.flat_map do |group_id|
            LabelsFinder.new(nil, finder_params.merge(group_id: group_id)).execute(skip_authorization: true)
          end
        end

        def find_project_labels(finder_params, group_ids, project_ids)
          # try group labels if no project_ids are provided or set to :any which means user has admin access
          return find_group_labels(finder_params, group_ids) if project_ids.blank? || project_ids == :any

          finder_params[:include_descendant_groups] = false
          finder_params[:include_ancestor_groups] = true

          project_ids.flat_map do |project_id|
            LabelsFinder.new(nil, finder_params.merge(project_id: project_id)).execute(skip_authorization: true)
          end
        end

        def group_labels_by_name(labels)
          labels.each_with_object(Hash.new { |h, k| h[k] = [] }) do |label, hash|
            hash[label.name] << label.id
          end
        end

        def search_level_filter(query_hash:, options:)
          user = options[:current_user]
          search_level = options[:search_level].to_sym
          namespace_ids = options[:group_ids]
          project_ids = scoped_project_ids(user, options[:project_ids])

          add_filter(query_hash, :query, :bool, :filter) do
            context.name(:filters, :level, search_level) do
              case search_level
              when :global
                nil # no-op
              when :group
                raise ArgumentError, 'No group_ids provided for group level search' if namespace_ids.empty?

                namespaces = Namespace.id_in(namespace_ids)
                traversal_ids = namespaces.map(&:elastic_namespace_ancestry)
                { bool:
                  { _name: context.name,
                    minimum_should_match: 1,
                    should: ancestry_filter(traversal_ids,
                      traversal_id_field: options.fetch(:traversal_ids_prefix, :traversal_ids)) } }
              when :project
                raise ArgumentError, 'No project_ids provided for project level search' if project_ids.empty?

                { bool:
                  { _name: context.name,
                    must: { terms: { project_id: project_ids } } } }
              end
            end
          end
        end

        def membership_filter(query_hash:, options:)
          features = Array.wrap(options[:features])
          user = options[:current_user]
          search_level = options[:search_level].to_sym
          # legacy query generation does not send this option
          visibility_level_field = options.fetch(:project_visibility_level_field, :visibility_level)

          add_filter(query_hash, :query, :bool, :filter) do
            context.name(:filters, :permissions, search_level) do
              permissions_filters = Search::Elastic::BoolExpr.new
              add_visibility_level_filter(permissions_filters:, user:, visibility_level_field:)
              add_feature_visibility_filter(permissions_filters, features, user)

              membership_filters = build_membership_filters(user, options, features)

              should = [{ bool: permissions_filters.to_h }]
              should << { bool: membership_filters.to_h } unless membership_filters.to_h.empty?

              {
                bool: {
                  _name: context.name,
                  should: should,
                  minimum_should_match: 1
                }
              }
            end
          end
        end

        def add_visibility_level_filter(permissions_filters:, user:, visibility_level_field:)
          return if user&.can_read_all_resources?

          add_filter(permissions_filters, :must) do
            visibility_level_for_user(user, visibility_level_field)
          end
        end

        def add_feature_visibility_filter(permissions_filters, features, user)
          return if features.blank?

          access_level_allowed = [::ProjectFeature::ENABLED]
          access_context_name = :enabled
          if user&.can_read_all_resources?
            access_level_allowed << ::ProjectFeature::PRIVATE
            access_context_name = :enabled_or_private
          end

          permissions_filters.minimum_should_match = 1
          features.each do |feature|
            add_filter(permissions_filters, :should) do
              {
                terms: {
                  _name: context.name(:"#{feature}_access_level", access_context_name),
                  "#{feature}_access_level": access_level_allowed
                }
              }
            end
          end
        end

        def build_membership_filters(user, options, features)
          membership_filters = Search::Elastic::BoolExpr.new
          return membership_filters if user&.can_read_all_resources?

          has_traversal_ids_filter = add_traversal_ids_filters(membership_filters, user, options)
          has_project_ids_filter = add_project_ids_filters(membership_filters, user, options)

          if (has_traversal_ids_filter || has_project_ids_filter) && features.present?
            add_feature_access_level_filter(membership_filters, features)
          end

          membership_filters
        end

        def add_traversal_ids_filters(membership_filters, user, options)
          traversal_ids = traversal_ids_for_user(user, options)
          return false if traversal_ids.blank?

          traversal_id_field_prefix = options.fetch(:traversal_ids_prefix, :traversal_ids)
          membership_filters.minimum_should_match = 1
          # ancestry_filter returns an array so add_filter cannot be used
          membership_filters.should += ancestry_filter(traversal_ids, traversal_id_field: traversal_id_field_prefix)

          true
        end

        def add_project_ids_filters(membership_filters, user, options)
          project_ids = project_ids_for_user(user, options)
          return false if project_ids.blank?

          # the builder queries set project_id_field, but legacy class proxy queries do not
          project_id_field = options.fetch(:project_id_field, :project_id)
          membership_filters.minimum_should_match = 1
          add_filter(membership_filters, :should) do
            {
              terms: {
                _name: context.name(:project, :member),
                "#{project_id_field}": project_ids
              }
            }
          end

          true
        end

        def add_feature_access_level_filter(membership_filters, features)
          feature_access_level_filter = Search::Elastic::BoolExpr.new
          feature_access_level_filter.minimum_should_match = 1
          features.each do |feature|
            add_filter(feature_access_level_filter, :should) do
              {
                terms: {
                  _name: context.name(:"#{feature}_access_level", :enabled_or_private),
                  "#{feature}_access_level": [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                }
              }
            end
          end

          membership_filters.minimum_should_match = 1
          add_filter(membership_filters, :filter) do
            { bool: feature_access_level_filter.to_h }
          end
        end
      end
    end
  end
end
