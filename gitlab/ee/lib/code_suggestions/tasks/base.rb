# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class Base
      AI_GATEWAY_CONTENT_SIZE = 100_000

      delegate :base_url, :self_hosted?, :feature_setting, :feature_name, :feature_disabled?, :licensed_feature,
        to: :model_details
      delegate :supports_sse_streaming?, to: :client

      def initialize(params: {}, unsafe_passthrough_params: {}, current_user: nil, client: nil)
        @params = params
        @unsafe_passthrough_params = unsafe_passthrough_params
        @client = client || CodeSuggestions::Client.new({})
        @current_user = current_user
      end

      def endpoint
        # TODO: After their migration to AIGW, both generations and completions will
        # use the same v3 `/completions` endpoint or v4 `/suggestions` endpoint.
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/477891.
        if task_name == 'code_generation' && !self_hosted?
          return "#{base_url}/v4/code/suggestions" if supports_sse_streaming?

          "#{base_url}/v3/code/completions"
        else
          "#{base_url}/v2/code/#{endpoint_name}"
        end
      end

      def body
        body_params = unsafe_passthrough_params.merge(prompt.request_params)

        trim_content_params(body_params)

        body_params.to_json
      end

      private

      attr_reader :params, :unsafe_passthrough_params, :client, :current_user

      def endpoint_name
        raise NotImplementedError
      end

      def model_details
        raise NotImplementedError
      end

      def task_name
        self.class.name.demodulize.underscore
      end

      def trim_content_params(body_params)
        return unless body_params[:current_file]

        body_params[:current_file][:content_above_cursor] =
          body_params[:current_file][:content_above_cursor].to_s.last(AI_GATEWAY_CONTENT_SIZE)
        body_params[:current_file][:content_below_cursor] =
          body_params[:current_file][:content_below_cursor].to_s.first(AI_GATEWAY_CONTENT_SIZE)
      end
    end
  end
end
