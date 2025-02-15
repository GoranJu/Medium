# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class FireworksQwen < CodeSuggestions::Prompts::Base
        GATEWAY_PROMPT_VERSION = 1
        MODEL_NAME = 'qwen2p5-coder-7b'
        MODEL_PROVIDER = 'fireworks_ai'

        def request_params
          {
            prompt_version: GATEWAY_PROMPT_VERSION,
            model_name: MODEL_NAME,
            model_provider: MODEL_PROVIDER
          }
        end
      end
    end
  end
end
