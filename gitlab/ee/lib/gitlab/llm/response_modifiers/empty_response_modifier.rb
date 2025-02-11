# frozen_string_literal: true

module Gitlab
  module Llm
    module ResponseModifiers
      class EmptyResponseModifier < ::Gitlab::Llm::BaseResponseModifier
        def initialize(message = nil, error_code: nil)
          @ai_response = { message: message }
          @error_code = error_code
        end

        def response_body
          @response_body ||= response_message
        end

        def response_message
          @response_body = ai_response[:message]
          @response_body += error_code_message if @error_code.present?
          @response_body || ""
        end

        def errors
          @errors ||= []
        end

        private

        def error_code_message
          url = "#{Gitlab::Saas.doc_url}/ee/user/gitlab_duo_chat/troubleshooting.html#error-#{@error_code.downcase}"
          " #{_('Error code')}: [#{@error_code}](#{url})"
        end
      end
    end
  end
end
