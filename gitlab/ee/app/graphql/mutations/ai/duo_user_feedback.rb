# frozen_string_literal: true

module Mutations
  module Ai
    class DuoUserFeedback < BaseMutation
      graphql_name 'DuoUserFeedback'

      include Routing::PseudonymizationHelper

      argument :agent_version_id, ::Types::GlobalIDType[::Ai::AgentVersion], required: false,
        description: "Global ID of the agent to answer the chat."
      argument :ai_message_id, GraphQL::Types::String, required: true, description: 'ID of the AI Message.'
      argument :tracking_event, ::Types::Tracking::EventInputType, required: false, description: 'Tracking event data.'

      def resolve(**args)
        raise_resource_not_available_error! unless current_user

        chat_storage = ::Gitlab::Llm::ChatStorage.new(current_user, args[:agent_version_id]&.model_id)
        message = chat_storage.messages.find { |m| m.id == args[:ai_message_id] }

        raise_resource_not_available_error! unless message

        chat_storage.set_has_feedback(message)

        track_snowplow_event(args[:tracking_event], message)

        { errors: [] }
      end

      private

      def track_snowplow_event(event, message)
        return unless event

        extra = event.extra.is_a?(Hash) ? event.extra.slice('improveWhat', 'didWhat', 'promptLocation') : {}

        Gitlab::Tracking.event(
          event.category,
          event.action,
          user: current_user,
          label: event.label,
          property: event.property,
          requestId: message.request_id,
          cleanedUrl: cleaned_url,
          **extra
        )
      end

      def cleaned_url
        url = context[:request].headers["Referer"]

        # Pseudo-anonymize the URL to remove identifiable information
        url = masked_referrer_url(url)

        return unless url

        uri = URI.parse(url)
        path = uri.path

        # Remove all numbers, as they do not provide any value
        path = path.gsub(/\d+/, '')

        # Remove repetitive slashes
        path.squeeze('/')
      end
    end
  end
end
