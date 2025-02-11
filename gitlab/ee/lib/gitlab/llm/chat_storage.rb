# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatStorage
      include Gitlab::Utils::StrongMemoize

      SUPPORTED_EXTRAS = ['resource_content'].freeze
      POSTGRESQL_STORAGE = "postgresql"
      REDIS_STORAGE = "redis"

      delegate :messages, :current_thread, to: :read_storage

      def initialize(user, agent_version_id = nil, thread = nil)
        @user = user
        @agent_version_id = agent_version_id
        @thread = thread
      end

      def add(message)
        postgres_storage.add(message)
        redis_storage.add(message) if ::Feature.disabled?(:duo_chat_drop_redis_storage, user)
      end

      def update_message_extras(request_id, key, value)
        raise ArgumentError, "The key #{key} is not supported" unless key.in?(SUPPORTED_EXTRAS)

        message = messages.find { |m| m.request_id == request_id }
        return unless message

        message.extras[key] = value
        postgres_storage.update_message_extras(message)
        redis_storage.update(message) if ::Feature.disabled?(:duo_chat_drop_redis_storage, user)
      end

      def set_has_feedback(message)
        postgres_storage.set_has_feedback(message)
        redis_storage.set_has_feedback(message) if ::Feature.disabled?(:duo_chat_drop_redis_storage, user)
      end

      def messages_by(filters = {})
        messages.select do |message|
          matches_filters?(message, filters)
        end
      end

      def last_conversation
        self.class.last_conversation(messages)
      end

      def self.last_conversation(messages)
        idx = messages.rindex(&:conversation_reset?)
        return messages unless idx
        return [] unless idx + 1 < messages.size

        messages[idx + 1..]
      end

      def messages_up_to(message_id)
        all = messages
        idx = all.rindex { |m| m.id == message_id }
        idx ? all.first(idx + 1) : []
      end

      def clear!
        postgres_storage.clear!
        redis_storage.clear! if ::Feature.disabled?(:duo_chat_drop_redis_storage, user)
      end

      private

      attr_reader :user, :agent_version_id, :thread

      def storage_class(type)
        "Gitlab::Llm::ChatStorage::#{type.camelize}".constantize
      end

      def matches_filters?(message, filters)
        return false if filters[:roles]&.exclude?(message.role)
        return false if filters[:request_ids]&.exclude?(message.request_id)

        true
      end

      def read_storage
        postgres_storage
      end

      def postgres_storage
        @postgres_storage ||= storage_class(POSTGRESQL_STORAGE)
          .new(user, agent_version_id, thread)
      end

      def redis_storage
        @redis_storage ||= storage_class(REDIS_STORAGE).new(user, agent_version_id)
      end
    end
  end
end
