# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatStorage
      # This class is deprecated. Do NOT add a new feature here.
      # We're moving to PostgreSQL https://gitlab.com/groups/gitlab-org/-/epics/15622.
      class Redis < Base
        # Expiration time of user messages should not be more than 90 days.
        # EXPIRE_TIME sets expiration time for the whole chat history stream (not
        # for individual messages) - so the stream is deleted after 3 days since
        # last message was added.  Because for each user's message there is also
        # a response, it means that maximum theoretical time of oldest message in
        # the stream is (MAX_MESSAGES / 2) * EXPIRE_TIME
        EXPIRE_TIME =  3.days
        MAX_MESSAGES = 50

        def add(message)
          cache_data(dump_message(message))
          clear_memoization(:messages)
        end

        def set_has_feedback(message)
          with_redis do |redis|
            redis.multi do |multi|
              multi.sadd(feedback_key, [message.id])
              multi.expire(feedback_key, EXPIRE_TIME)
            end
          end
          clear_memoization(:messages)
        end

        def messages
          with_redis do |redis|
            feedback_markers = redis.smembers(feedback_key)
            redis.xrange(key).map do |_id, data|
              load_message(data).tap do |message|
                message.extras['has_feedback'] = feedback_markers.include?(message.id)
              end
            end
          end
        end
        strong_memoize_attr :messages

        def clear!
          with_redis do |redis|
            redis.xtrim(key, 0)
            redis.del(feedback_key)
          end
          clear_memoization(:messages)
        end

        # Redis streams are immutable, so we must first delete all the messages
        # and then re-add them along with the updated message in the same order.
        def update(message)
          with_redis do |redis|
            redis.multi do |multi|
              multi.xtrim(key, 0)
              messages.each do |m|
                if m.id == message.id
                  multi.xadd(key, dump_message(message))
                else
                  multi.xadd(key, dump_message(m))
                end
              end
              multi.expire(key, EXPIRE_TIME)
            end
          end
          clear_memoization(:messages)
        end

        def current_thread
          # no-op
        end

        private

        attr_reader :user, :agent_version_id

        def cache_data(data)
          with_redis do |redis|
            redis.multi do |multi|
              multi.xadd(key, data, maxlen: MAX_MESSAGES)
              multi.expire(key, EXPIRE_TIME)
            end
          end
        end

        def key
          return "ai_chat:#{user.id}:#{agent_version_id}" if agent_version_id

          "ai_chat:#{user.id}"
        end

        def feedback_key
          "#{key}:feedback"
        end

        def with_redis(&block)
          Gitlab::Redis::Chat.with(&block) # rubocop: disable CodeReuse/ActiveRecord -- We are deprecating this class so it is not necessary to refactor this.
        end
      end
    end
  end
end
