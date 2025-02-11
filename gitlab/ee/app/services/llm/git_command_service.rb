# frozen_string_literal: true

module Llm
  class GitCommandService < BaseService
    TEMPERATURE = 0.4
    INPUT_CONTENT_LIMIT = 300
    MAX_RESPONSE_TOKENS = 300

    def valid?
      options[:prompt].size < INPUT_CONTENT_LIMIT &&
        user.can?(:access_glab_ask_git_command)
    end

    private

    def ai_action
      :glab_ask_git_command
    end

    def perform
      response = ::Gitlab::Llm::AiGateway::Client.new(user, service_name: :glab_ask_git_command)
        .complete(
          url: "#{::Gitlab::AiGateway.url}/v1/prompts/glab_ask_git_command",
          body: { 'inputs' => options }
        )

      response_modifier = ::Gitlab::Llm::AiGateway::ResponseModifiers::GitCommand.new(Gitlab::Json.parse(response.body))

      success(response_modifier.response_body)
    end
  end
end
