# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeGeneration
      class AiGatewaySelfHostedMessages < CodeSuggestions::Prompts::Base
        GATEWAY_PROMPT_VERSION = 2
        MODEL_PROVIDER = 'litellm'
        PROMPT_ID = 'code_suggestions/generations'

        attr_reader :feature_setting

        def initialize(feature_setting:, params:, current_user:)
          @feature_setting = feature_setting

          super(params, current_user)
        end

        def request_params
          self_hosted_model = feature_setting&.self_hosted_model

          {
            model_provider: self.class::MODEL_PROVIDER,
            prompt: prompt,
            model_endpoint: self_hosted_model&.endpoint,
            model_api_key: self_hosted_model&.api_token,
            model_name: self_hosted_model&.model,
            model_identifier: self_hosted_model&.identifier
          }.merge(extra_params)
        end

        private

        def extra_params
          {
            prompt_version: self.class::GATEWAY_PROMPT_VERSION,
            prompt_id: PROMPT_ID
          }
        end

        def prompt
          params[:instruction]&.instruction.presence || ""
        end

        def pick_content_above_cursor
          content_above_cursor.last(500)
        end

        def pick_content_below_cursor
          content_below_cursor.first(500)
        end
      end
    end
  end
end
