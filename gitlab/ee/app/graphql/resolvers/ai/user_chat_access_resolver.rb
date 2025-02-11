# frozen_string_literal: true

module Resolvers
  module Ai
    class UserChatAccessResolver < BaseResolver
      type ::GraphQL::Types::Boolean, null: false

      def resolve
        return false unless current_user

        Feature.enabled?(:ai_duo_chat_switch, type: :ops) &&
          ::Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: current_user).allowed?
      end
    end
  end
end
