# frozen_string_literal: true

module Resolvers
  module Ai
    class ChatMessagesResolver < BaseResolver
      type Types::Ai::MessageType, null: false

      argument :request_ids, [GraphQL::Types::ID],
        required: false,
        description: 'Array of request IDs to fetch.'

      argument :roles, [Types::Ai::MessageRoleEnum],
        required: false,
        description: 'Array of roles to fetch.'

      argument :conversation_type, Types::Ai::Conversations::Threads::ConversationTypeEnum,
        required: false,
        description: 'Conversation type of the thread.'

      argument :thread_id,
        ::Types::GlobalIDType[::Ai::Conversation::Thread],
        required: false,
        description: 'Global Id of the existing thread.' \
          'If it is not specified, the last thread for the specified conversation_type will be retrieved.'

      argument :agent_version_id,
        ::Types::GlobalIDType[::Ai::AgentVersion],
        required: false,
        description: "Global ID of the agent to answer the chat."

      def resolve(**args)
        return [] unless current_user

        agent_version_id = args[:agent_version_id]&.model_id
        thread = find_thread(args)

        ::Gitlab::Llm::ChatStorage.new(current_user, agent_version_id, thread).messages_by(args).map(&:to_h)
      end

      private

      def find_thread(args)
        find_thread_by_id(args[:thread_id]) ||
          find_thread_by_conversation_type(args[:conversation_type])
      end

      def find_thread_by_id(thread_id)
        return unless thread_id

        current_user.ai_conversation_threads.find(thread_id.model_id)
      rescue ActiveRecord::RecordNotFound
        raise Gitlab::Graphql::Errors::ArgumentError, "Thread #{thread_id.model_id} is not found."
      end

      def find_thread_by_conversation_type(conversation_type)
        return unless conversation_type

        current_user.ai_conversation_threads.for_conversation_type(conversation_type).last
      end
    end
  end
end
