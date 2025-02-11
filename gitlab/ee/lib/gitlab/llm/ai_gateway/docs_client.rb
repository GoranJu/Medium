# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      class DocsClient
        include ::Gitlab::Llm::Concerns::ExponentialBackoff
        include ::Gitlab::Llm::Concerns::EventTracking
        include ::Gitlab::Utils::StrongMemoize
        include ::Gitlab::Llm::Concerns::Logger

        DEFAULT_TIMEOUT = 30.seconds
        DEFAULT_TYPE = 'search-docs'
        DEFAULT_SOURCE = 'GitLab EE'

        def initialize(user, tracking_context: {})
          @user = user
          @tracking_context = tracking_context
        end

        def search(query:, **options)
          return unless enabled?

          perform_search_request(query: query, options: options)
        end

        private

        attr_reader :user, :tracking_context

        def perform_search_request(query:, options:)
          log_info(message: "Searching docs from AI Gateway",
            event_name: 'performing_request',
            ai_component: 'duo_chat',
            options: options)
          timeout = options.delete(:timeout) || DEFAULT_TIMEOUT

          response = Gitlab::HTTP.post(
            "#{Gitlab::AiGateway.url}/v1/search/gitlab-docs",
            headers: Gitlab::AiGateway.headers(user: user, service: service),
            body: request_body(query: query).to_json,
            timeout: timeout,
            allow_local_requests: true
          )

          log_conditional_info(user,
            message: "Searched docs content from AI Gateway",
            event_name: 'response_received',
            ai_component: 'duo_chat',
            response_from_llm: response)

          response
        end

        def enabled?
          access_token.present?
        end

        def service
          chat_feature_setting = ::Ai::FeatureSetting.find_by_feature(:duo_chat)
          feature_name = chat_feature_setting&.self_hosted? ? :self_hosted_models : :duo_chat

          ::CloudConnector::AvailableServices.find_by_name(feature_name)
        end
        strong_memoize_attr :service

        def access_token
          service.access_token(user)
        end
        strong_memoize_attr :access_token

        def request_body(query:)
          {
            type: DEFAULT_TYPE,
            metadata: {
              source: DEFAULT_SOURCE,
              version: Gitlab.version_info.to_s
            },
            payload: {
              query: query
            }
          }
        end
      end
    end
  end
end
