# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class AiUserMetricsService
      CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY = <<~SQL.freeze
        SELECT SUM(occurrences) as code_suggestions_accepted_count, user_id
        FROM code_suggestion_daily_events
        WHERE user_id IN ({user_ids:Array(UInt64)})
        AND date >= {from:Date}
        AND date <= {to:Date}
        AND event = #{::Ai::CodeSuggestionEvent.events['code_suggestion_accepted_in_ide']}
        GROUP BY user_id
      SQL
      private_constant :CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY

      DUO_CHAT_INTERACTIONS_COUNT_QUERY = <<~SQL
        SELECT SUM(occurrences) as duo_chat_interactions_count, user_id
        FROM duo_chat_daily_events
        WHERE user_id IN ({user_ids:Array(UInt64)})
        AND date >= {from:Date}
        AND date <= {to:Date}
        AND event = 1
        GROUP BY user_id
      SQL
      private_constant :DUO_CHAT_INTERACTIONS_COUNT_QUERY

      def initialize(current_user, namespace:, from:, to:, user_ids:)
        @current_user = current_user
        @namespace = namespace
        @from = from
        @to = to
        @user_ids = user_ids
      end

      def execute
        return feature_unavailable_error unless Gitlab::ClickHouse.enabled_for_analytics?(namespace)

        data = code_suggestions_usage_data
        data = duo_chat_interactions_data(data)

        ServiceResponse.success(payload: data)
      end

      private

      attr_reader :current_user, :namespace, :from, :to, :user_ids

      def code_suggestions_usage_data(data = {})
        usage_data(data, CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY, :code_suggestions_accepted_count)
      end

      def duo_chat_interactions_data(data = {})
        usage_data(data, DUO_CHAT_INTERACTIONS_COUNT_QUERY, :duo_chat_interactions_count)
      end

      def usage_data(data, raw_query, field)
        query = ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)
        ClickHouse::Client.select(query, :main).each do |row|
          data[row['user_id']] ||= {}
          data[row['user_id']][field] = row[field.to_s]
        end

        data
      end

      def placeholders
        {
          from: from.to_date.iso8601,
          to: to.to_date.iso8601,
          user_ids: user_ids.to_json
        }
      end

      def feature_unavailable_error
        ServiceResponse.error(
          message: s_('AiAnalytics|the ClickHouse data store is not available')
        )
      end
    end
  end
end
