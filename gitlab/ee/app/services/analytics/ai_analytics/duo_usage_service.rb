# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class DuoUsageService
      include CommonUsageService

      QUERY = <<~SQL
        -- cte to load contributors
        WITH contributors AS (
          SELECT DISTINCT author_id
          FROM contributions
          WHERE startsWith(path, {traversal_path:String})
          AND "contributions"."created_at" >= {from:Date}
          AND "contributions"."created_at" <= {to:Date}
        )
        SELECT %{fields}
      SQL

      DUO_USED_COUNT_QUERY = <<~SQL
        SELECT COUNT(user_id) FROM (
          SELECT DISTINCT user_id
          FROM duo_chat_daily_events
          WHERE user_id IN (SELECT author_id FROM contributors)
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event = 1
          UNION DISTINCT
          SELECT DISTINCT user_id
          FROM code_suggestion_daily_events
          WHERE user_id IN (SELECT author_id FROM contributors)
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event IN (1,2,3,5)
        )
      SQL
      private_constant :DUO_USED_COUNT_QUERY

      FIELDS_SUBQUERIES = {
        duo_used_count: DUO_USED_COUNT_QUERY
      }.freeze

      FIELDS = FIELDS_SUBQUERIES.keys
    end
  end
end
