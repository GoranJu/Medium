# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatStorage
      class Postgresql < Base
        DEFAULT_CONVERSATION_TYPE = :duo_chat
        MAX_MESSAGES = 50

        def add(message)
          data = dump_message(message)

          data['message_xid'] = data.delete('id') if data['id']
          data['error_details'] = data.delete('errors') if data['errors']
          data['request_xid'] = data.delete('request_id') if data['request_id']
          data.delete('timestamp') if data['timestamp']

          current_thread.messages.create!(**data)
          current_thread.update_column(:last_updated_at, Time.current)
          clear_memoization(:messages)
        end

        def set_has_feedback(message)
          user.ai_conversation_messages.for_message_xid(message.id).update!(has_feedback: true)
          clear_memoization(:messages)
        end

        def messages
          current_thread.messages.recent(MAX_MESSAGES).map do |message|
            data = message.as_json

            data['id'] = data.delete('message_xid') if data['message_xid']
            data['errors'] = data.delete('error_details') if data['error_details']
            data['request_id'] = data['request_xid'] if data['request_xid']
            data['timestamp'] = data['created_at']

            msg = load_message(data)

            msg.extras['has_feedback'] = data.delete('has_feedback') if data['has_feedback']

            msg
          end
        end
        strong_memoize_attr :messages

        def clear!
          @current_thread = current_thread.to_new_thread!
          clear_memoization(:messages)
        end

        def update_message_extras(message)
          user.ai_conversation_messages.for_message_xid(message.id).update!(extras: message.extras.to_json)
          clear_memoization(:messages)
        end

        def current_thread
          @current_thread ||= thread || find_default_thread || create_default_thread
        end

        private

        def find_default_thread
          user.ai_conversation_threads.for_conversation_type(DEFAULT_CONVERSATION_TYPE).last
        end

        def create_default_thread
          user.ai_conversation_threads.create!(conversation_type: DEFAULT_CONVERSATION_TYPE)
        end
      end
    end
  end
end
