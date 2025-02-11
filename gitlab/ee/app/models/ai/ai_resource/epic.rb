# frozen_string_literal: true

module Ai
  module AiResource
    class Epic < Ai::AiResource::BaseAiResource
      include Ai::AiResource::Concerns::Noteable

      def serialize_for_ai(content_limit:)
        ::EpicSerializer.new(current_user: current_user) # rubocop: disable CodeReuse/Serializer
                        .represent(resource, {
                          user: current_user,
                          notes_limit: content_limit,
                          serializer: 'ai',
                          resource: self
                        })
      end

      def current_page_type
        "epic"
      end

      def current_page_short_description
        <<~SENTENCE
          The user is currently on a page that displays an epic with a description, comments, etc., which the user might refer to, for example, as 'current', 'this' or 'that'. The title of the epic is '#{resource.title}'.
        SENTENCE
      end
    end
  end
end
