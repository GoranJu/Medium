# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatStorage
      class Base
        include Gitlab::Utils::StrongMemoize
        include ::Gitlab::Llm::Concerns::Logger

        # AI provider-specific limits are applied to requests/responses. To not
        # rely only on third-party limits and assure that cache usage can't be
        # exhausted by users by sending huge texts/responses, we apply also
        # safeguard limit on maximum size of cached response. 1 token ~= 4 chars
        # in English, limit is typically ~4100 -> so 20000 char limit should be
        # sufficient.
        MAX_TEXT_LIMIT = 20_000

        def initialize(user, agent_version_id = nil, thread = nil)
          @thread = thread
          @agent_version_id = agent_version_id
          @user = user
        end

        def add(message)
          raise NotImplementedError
        end

        def set_has_feedback(message)
          raise NotImplementedError
        end

        def messages
          raise NotImplementedError
        end

        def clear!
          raise NotImplementedError
        end

        private

        attr_reader :user, :agent_version_id, :thread

        def dump_message(message)
          # Message is stored only partially. Some data might be missing after reloading from storage.
          result = message.to_h.slice(*%w[id request_id role content referer_url])

          extras = message.extras
          if message.additional_context.present?
            extras ||= {}
            extras['additional_context'] = message.additional_context.to_a
          end

          result['errors'] = message.errors&.to_json
          result['extras'] = extras&.to_json
          result['timestamp'] = message.timestamp&.to_s
          result['content'] = result['content'][0, MAX_TEXT_LIMIT] if result['content']

          result.compact
        end

        def load_message(data)
          data['extras'] = ::Gitlab::Json.parse(data['extras']) if data['extras']
          data['errors'] = ::Gitlab::Json.parse(data['errors']) if data['errors']
          data['timestamp'] = Time.zone.parse(data['timestamp']) if data['timestamp']
          data['ai_action'] = 'chat'
          data['user'] = user
          data['agent_version_id'] = agent_version_id

          ChatMessage.new(data)
        end
      end
    end
  end
end
