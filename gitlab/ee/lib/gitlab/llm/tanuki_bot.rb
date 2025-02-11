# frozen_string_literal: true

module Gitlab
  module Llm
    class TanukiBot
      def self.enabled_for?(user:, container: nil)
        return false unless chat_enabled?(user)

        authorizer_response = if container
                                Gitlab::Llm::Chain::Utils::ChatAuthorizer.container(container: container, user: user)
                              else
                                Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: user)
                              end

        authorizer_response.allowed?
      end

      def self.show_breadcrumbs_entry_point?(user:, container: nil)
        return false unless chat_enabled?(user) && container

        Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: user).allowed?
      end

      def self.chat_disabled_reason(user:, container: nil)
        return unless container

        authorizer_response = Gitlab::Llm::Chain::Utils::ChatAuthorizer.container(container: container, user: user)
        return if authorizer_response.allowed?

        container.is_a?(Group) ? :group : :project
      end

      def self.chat_enabled?(user)
        return false unless Feature.enabled?(:ai_duo_chat_switch, type: :ops)
        return false unless user

        true
      end

      def self.resource_id
        Gitlab::ApplicationContext.current_context_attribute(:ai_resource).presence
      end

      def self.project_id
        project_path = Gitlab::ApplicationContext.current_context_attribute(:project).presence
        Project.find_by_full_path(project_path).try(:to_global_id) if project_path
      end
    end
  end
end
