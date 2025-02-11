# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class CodeCompletion < Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      delegate :saas_primary_model_class, to: :model_details

      override :endpoint_name
      def endpoint_name
        'completions'
      end

      private

      def model_details
        @model_details ||= CodeSuggestions::ModelDetails::CodeCompletion.new(current_user: current_user)
      end

      def prompt
        if Feature.enabled?(:amazon_q_chat_and_code_suggestions, current_user) && ::Ai::AmazonQ.connected?
          amazon_q_prompt
        elsif self_hosted?
          self_hosted_prompt
        else
          saas_prompt
        end
      end
      strong_memoize_attr :prompt

      def self_hosted_prompt
        CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeCompletionMessage.new(
          feature_setting: feature_setting, params: params, current_user: current_user)
      end

      def saas_prompt
        if Feature.enabled?(:incident_fail_over_completion_provider, current_user)
          # claude hosted on anthropic
          CodeSuggestions::Prompts::CodeCompletion::Anthropic.new(params, current_user)
        else
          saas_primary_model_class.new(params, current_user)
        end
      end

      def amazon_q_prompt
        CodeSuggestions::Prompts::CodeCompletion::AmazonQ.new(params, current_user)
      end
    end
  end
end
