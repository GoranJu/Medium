# frozen_string_literal: true

module Ai
  module AiResource
    class Issue < Ai::AiResource::BaseAiResource
      include Ai::AiResource::Concerns::Noteable

      def serialize_for_ai(content_limit:)
        ::IssueSerializer.new(current_user: current_user, project: resource.project) # rubocop: disable CodeReuse/Serializer
                         .represent(resource, {
                           user: current_user,
                           notes_limit: content_limit,
                           serializer: 'ai',
                           resource: self
                         })
      end

      def current_page_type
        "issue"
      end

      def current_page_short_description
        <<~SENTENCE
          The user is currently on a page that displays an issue with a description, comments, etc., which the user might refer to, for example, as 'current', 'this' or 'that'. The title of the issue is '#{resource.title}'.
        SENTENCE
      end
    end
  end
end
