# frozen_string_literal: true

module Ai
  class CodeSuggestionEventsFinder
    attr_reader :resource, :current_user

    CONTRIBUTORS_IDS_QUERY = <<~SQL
      SELECT DISTINCT author_id
      FROM contributions
      WHERE startsWith(path, {traversal_path:String})
      AND "contributions"."action" = 5
    SQL
    private_constant :CONTRIBUTORS_IDS_QUERY

    def initialize(current_user, resource:)
      @current_user = current_user
      @resource = resource
    end

    def execute
      return ::Ai::CodeSuggestionEvent.none unless Ability.allowed?(current_user, :read_enterprise_ai_analytics,
        resource)

      # rubocop: disable CodeReuse/ActiveRecord -- will be replaced after namespace_path is populated at ai_code_suggestion_events
      ::Ai::CodeSuggestionEvent.where(user_id: contributors_ids)
      # rubocop: enable CodeReuse/ActiveRecord
    end

    private

    # In this first iteration we consider users a contributor for a
    # group in two ways:
    # * When CH is available - All users that pushed to a project that belongs to the group at any time
    # * When CH is unavailable - Users that pushed to a project that belongs to the group in the last seven days
    # This is a temporary solution until `namespace_path` on `ai_code_suggestions` table is populated
    # and filtering by groups/projects implemented, after https://gitlab.com/gitlab-org/gitlab/-/issues/490601
    # we can move this logic to Ai::CodeSuggestionEvent model.
    def contributors_ids
      if ::Gitlab::ClickHouse.enabled_for_analytics?(resource)
        contributors_ids_from_ch
      else
        contributors_ids_from_postgresql
      end
    end

    # Users that pushed code in the last seven days
    # rubocop: disable CodeReuse/ActiveRecord -- Will be moved to model after refactoring on https://gitlab.com/gitlab-org/gitlab/-/issues/490601
    def contributors_ids_from_postgresql
      Event.pushed_action
        .where('created_at >= ?', 1.week.ago.beginning_of_day)
        .where(project_id: Project.for_group_and_its_subgroups(resource))
        .select('DISTINCT author_id')
    end

    def contributors_ids_from_ch
      variables =
        {
          traversal_path: resource.traversal_path
        }

      query =
        ClickHouse::Client::Query.new(raw_query: CONTRIBUTORS_IDS_QUERY, placeholders: variables)

      contributors = ClickHouse::Client.select(query, :main)

      # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- will be removed after namespace_path is populated at ai_code_suggestion_events
      contributors.pluck('author_id')
      # rubocop: enable Database/AvoidUsingPluckWithoutLimit
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
