# frozen_string_literal: true

# Deprecation: ReactExecutor doesn't use this modifier
# as picked_tool_action method isn't used anymore.
# This class will be removed alongside ZeroShot::Executor
# see https://gitlab.com/gitlab-org/gitlab/-/issues/469087

module Gitlab
  module Llm
    module Chain
      class ToolResponseModifier < Gitlab::Llm::BaseResponseModifier
        def initialize(tool_class)
          @ai_response = tool_class
        end

        def response_body
          @response_body ||= ai_response::HUMAN_NAME
        end

        def errors
          @errors ||= []
        end
      end
    end
  end
end
