# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module Completions
        class Base < Llm::Completions::Base
          DEFAULT_ERROR = 'An unexpected error has occurred.'
          RESPONSE_MODIFIER = ResponseModifiers::Base

          def execute
            return unless valid?

            response = request!
            response_modifier = self.class::RESPONSE_MODIFIER.new(post_process(response))

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, resource, response_modifier, options: response_options
            ).execute
          end

          # Subclasses must implement this method returning a Hash with all the needed input.
          # An `ArgumentError` can be emitted to signal an error extracting data from the `prompt_message`
          def inputs
            raise NotImplementedError
          end

          private

          # Can be overwritten by child classes to perform additional validations
          def valid?
            true
          end

          # Can be used by subclasses to perform additional steps or transformations before returning the response data
          def post_process(response)
            response
          end

          def request!
            ai_client = ::Gitlab::Llm::AiGateway::Client.new(user, service_name: service_name,
              tracking_context: tracking_context)
            response = ai_client.complete(
              url: "#{::Gitlab::AiGateway.url}/v1/prompts/#{prompt_message.ai_action}",
              body: { 'inputs' => inputs }
            )

            return if response&.body.blank?
            return Gitlab::Json.parse(response.body) if response&.success?

            { 'detail' => DEFAULT_ERROR }
          rescue ArgumentError => e
            { 'detail' => e.message }
          rescue StandardError => e
            Gitlab::ErrorTracking.track_exception(e, ai_action: prompt_message.ai_action)

            { 'detail' => DEFAULT_ERROR }
          end

          def service_name
            prompt_message.ai_action.to_sym
          end
        end
      end
    end
  end
end
