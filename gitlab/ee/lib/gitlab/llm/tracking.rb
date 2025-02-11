# frozen_string_literal: true

module Gitlab
  module Llm
    class Tracking
      USER_AGENT_CLIENTS = {
        UsageDataCounters::VSCodeExtensionActivityUniqueCounter::VS_CODE_USER_AGENT_REGEX =>
          'vscode',
        UsageDataCounters::JetBrainsPluginActivityUniqueCounter::JETBRAINS_USER_AGENT_REGEX =>
          'jetbrains',
        UsageDataCounters::JetBrainsBundledPluginActivityUniqueCounter::JETBRAINS_BUNDLED_USER_AGENT_REGEX =>
          'jetbrains_bundled',
        UsageDataCounters::VisualStudioExtensionActivityUniqueCounter::VISUAL_STUDIO_EXTENSION_USER_AGENT_REGEX =>
          'visual_studio',
        UsageDataCounters::NeovimPluginActivityUniqueCounter::NEOVIM_PLUGIN_USER_AGENT_REGEX =>
          'neovim',
        UsageDataCounters::GitLabCliActivityUniqueCounter::GITLAB_CLI_USER_AGENT_REGEX =>
          'gitlab_cli'
      }.freeze

      def self.event_for_ai_message(category, action, ai_message:)
        ::Gitlab::Tracking.event(
          category,
          action,
          label: ai_message.ai_action.to_s,
          property: ai_message.request_id,
          user: ai_message.user,
          client: client_for_user_agent(ai_message.context.user_agent)
        )
      end

      def self.client_for_user_agent(user_agent)
        return unless user_agent.present?

        USER_AGENT_CLIENTS.find { |regex, _client| user_agent.match?(regex) }&.last || 'web'
      end
    end
  end
end
