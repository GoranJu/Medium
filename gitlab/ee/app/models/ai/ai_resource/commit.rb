# frozen_string_literal: true

module Ai
  module AiResource
    class Commit < Ai::AiResource::BaseAiResource
      include Ai::AiResource::Concerns::Noteable

      def serialize_for_ai(content_limit:)
        EE::CommitSerializer # rubocop:disable CodeReuse/Serializer -- existing serializer
          .new(current_user: current_user, project: resource.project)
          .represent(resource, {
            user: current_user,
            notes_limit: content_limit,
            serializer: 'ai',
            resource: self
          })
      end

      def current_page_type
        "commit"
      end

      def current_page_short_description
        return '' unless Feature.enabled?(:ai_commit_reader_for_chat, current_user)

        <<~SENTENCE
          The user is currently on a page that displays a commit with a description, comments, etc., which the user might refer to, for example, as 'current', 'this' or 'that'. The title of the commit is '#{resource.title}'.
        SENTENCE
      end
    end
  end
end
