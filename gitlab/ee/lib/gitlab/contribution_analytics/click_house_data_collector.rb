# frozen_string_literal: true

module Gitlab
  module ContributionAnalytics
    class ClickHouseDataCollector
      QUERY = <<~CH
        SELECT count(*) AS count,
          "contributions"."author_id" AS author_id,
          "contributions"."target_type" AS target_type,
          "contributions"."action" AS action
        FROM (
          SELECT
            id,
            argMax(author_id, contributions.updated_at) AS author_id,
            argMax(target_type, contributions.updated_at) AS target_type,
            argMax(action, contributions.updated_at) AS action
          FROM contributions
            WHERE startsWith(path, {group_path:String})
            AND "contributions"."created_at" >= {from:Date}
            AND "contributions"."created_at" <= {to:Date}
            AND (
              (
                "contributions"."action" = 5 AND "contributions"."target_type" = ''
              )
              OR
              (
                "contributions"."action" IN (1, 3, 7, 12)
                AND "contributions"."target_type" IN ('MergeRequest', 'Issue')
              )
            )
          GROUP BY id
        ) contributions
        GROUP BY "contributions"."action","contributions"."target_type","contributions"."author_id"
      CH

      attr_reader :group, :from, :to

      def initialize(group:, from:, to:)
        @group = group
        @from = from
        @to = to
      end

      def totals_by_author_target_type_action
        query = ::ClickHouse::Client::Query.new(raw_query: QUERY, placeholders: placeholders)
        ::ClickHouse::Client.select(query, :main).each_with_object({}) do |row, hash|
          hash[[row['author_id'], row['target_type'].presence, row['action']]] = row['count']
        end
      end

      private

      def group_path
        # trailing slash required to denote end of path because we use startsWith
        # to get self and descendants
        @group_path ||= group.traversal_path
      end

      def format_date(date)
        date.utc.to_date.iso8601
      end

      def placeholders
        {
          group_path: group_path,
          from: format_date(from),
          to: format_date(to)
        }
      end
    end
  end
end
