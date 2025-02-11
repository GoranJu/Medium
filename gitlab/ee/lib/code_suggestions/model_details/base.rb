# frozen_string_literal: true

module CodeSuggestions
  module ModelDetails
    class Base
      include Gitlab::Utils::StrongMemoize

      def initialize(current_user:, feature_setting_name:)
        @current_user = current_user
        @feature_setting_name = feature_setting_name
      end

      def feature_setting
        ::Ai::FeatureSetting.find_by_feature(feature_setting_name)
      end
      strong_memoize_attr :feature_setting

      def base_url
        feature_setting&.base_url || Gitlab::AiGateway.url
      end

      def feature_name
        return :amazon_q_integration if Feature.enabled?(:amazon_q_chat_and_code_suggestions,
          current_user) && ::Ai::AmazonQ.connected?

        return :self_hosted_models if self_hosted?

        :code_suggestions
      end

      def licensed_feature
        return :amazon_q if Feature.enabled?(:amazon_q_chat_and_code_suggestions,
          current_user) && ::Ai::AmazonQ.connected?

        :ai_features
      end

      def feature_disabled?
        # In case the code suggestions feature is being used via self-hosted models,
        # it can also be disabled completely. In such cases, this check
        # can be used to prevent exposing the feature via UI/API.
        !!feature_setting&.disabled?
      end

      def self_hosted?
        !!feature_setting&.self_hosted?
      end

      private

      attr_reader :current_user, :feature_setting_name
    end
  end
end
