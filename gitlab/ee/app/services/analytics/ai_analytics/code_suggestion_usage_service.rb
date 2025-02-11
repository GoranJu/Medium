# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class CodeSuggestionUsageService
      include CommonUsageService

      QUERY = <<~SQL
        -- cte to load code contributors
        WITH code_contributors AS (
          SELECT DISTINCT author_id
          FROM contributions
          WHERE startsWith(path, {traversal_path:String})
          AND "contributions"."created_at" >= {from:Date}
          AND "contributions"."created_at" <= {to:Date}
          AND "contributions"."action" = 5
        )
        SELECT %{fields}
      SQL

      CODE_CONTRIBUTORS_COUNT_QUERY = "SELECT count(*) FROM code_contributors"
      private_constant :CODE_CONTRIBUTORS_COUNT_QUERY

      code_suggestion_usage_events = ::Ai::CodeSuggestionEvent.events.values_at(
        'code_suggestions_requested',
        'code_suggestion_shown_in_ide',
        'code_suggestion_direct_access_token_refresh'
      ).join(', ')

      CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY = <<~SQL.freeze
        SELECT COUNT(DISTINCT user_id)
          FROM code_suggestion_daily_events
          WHERE user_id IN (SELECT author_id FROM code_contributors)
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event IN (#{code_suggestion_usage_events})
      SQL
      private_constant :CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY

      CODE_SUGGESTIONS_SHOWN_COUNT_QUERY = <<~SQL.freeze
        SELECT SUM(occurrences)
        FROM code_suggestion_daily_events
        WHERE user_id IN (SELECT author_id FROM code_contributors)
        AND date >= {from:Date}
        AND date <= {to:Date}
        AND event = #{::Ai::CodeSuggestionEvent.events['code_suggestion_shown_in_ide']}
      SQL
      private_constant :CODE_SUGGESTIONS_SHOWN_COUNT_QUERY

      CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY = <<~SQL.freeze
        SELECT SUM(occurrences)
        FROM code_suggestion_daily_events
        WHERE user_id IN (SELECT author_id FROM code_contributors)
        AND date >= {from:Date}
        AND date <= {to:Date}
        AND event = #{::Ai::CodeSuggestionEvent.events['code_suggestion_accepted_in_ide']}
      SQL
      private_constant :CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY

      FIELDS_SUBQUERIES = {
        code_contributors_count: CODE_CONTRIBUTORS_COUNT_QUERY,
        code_suggestions_contributors_count: CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY,
        code_suggestions_shown_count: CODE_SUGGESTIONS_SHOWN_COUNT_QUERY,
        code_suggestions_accepted_count: CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY

      }.freeze

      FIELDS = FIELDS_SUBQUERIES.keys
    end
  end
end
