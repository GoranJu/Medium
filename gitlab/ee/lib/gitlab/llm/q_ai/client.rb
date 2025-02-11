# frozen_string_literal: true

module Gitlab
  module Llm
    module QAi
      class Client
        include ::Gitlab::Llm::Concerns::Logger

        def initialize(user)
          @user = user
        end

        def perform_create_auth_application(oauth_app, secret, role_arn)
          payload = {
            client_id: oauth_app.uid.to_s,
            client_secret: secret,
            redirect_url: oauth_app.redirect_uri,
            instance_url: Gitlab.config.gitlab.url,
            role_arn: role_arn
          }

          with_response_logger do
            Gitlab::HTTP.post(
              url(path: "/v1/amazon_q/oauth/application"),
              body: payload.to_json,
              headers: request_headers
            )
          end
        end

        def create_event(payload:, auth_grant:, role_arn:)
          with_response_logger do
            Gitlab::HTTP.post(
              url(path: "/v1/amazon_q/events"),
              body: {
                payload: payload,
                code: auth_grant,
                role_arn: role_arn
              }.to_json,
              headers: request_headers
            )
          end
        end

        private

        attr_reader :user

        def url(path:)
          # use append_path to handle potential trailing slash in AI Gateway URL
          Gitlab::Utils.append_path(Gitlab::AiGateway.url, path)
        end

        def service_name
          :amazon_q_integration
        end

        def service
          ::CloudConnector::AvailableServices.find_by_name(service_name)
        end

        def request_headers
          {
            "Accept" => "application/json",
            # Note: In this case, the service is the same as the unit primitive name
            'X-Gitlab-Unit-Primitive' => service_name.to_s
          }.merge(Gitlab::AiGateway.headers(user: user, service: service))
        end

        def with_response_logger
          yield.tap do |response|
            log_server_response(response)
          end
        end

        def log_server_response(response)
          if response.success?
            log_server_success(response)
          else
            log_server_error(response)
          end
        end

        def log_server_error(response)
          body = response.parsed_response['detail'] if response.parsed_response.is_a?(Hash)

          log_error(message: 'Error response from AI Gateway',
            event_name: 'error_response_received',
            ai_component: 'abstraction_layer',
            status: response.code,
            body: body)
        end

        def log_server_success(response)
          log_conditional_info(user,
            message: 'Received successful response from AI Gateway',
            ai_component: 'abstraction_layer',
            status: response.code,
            event_name: 'response_received')
        end
      end
    end
  end
end
