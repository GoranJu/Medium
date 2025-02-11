# frozen_string_literal: true

module Ai
  module AiResource
    class MergeRequest < Ai::AiResource::BaseAiResource
      include Ai::AiResource::Concerns::Noteable

      def serialize_for_ai(content_limit:)
        ::MergeRequestSerializer.new(current_user: current_user) # rubocop: disable CodeReuse/Serializer -- existing serializer
                        .represent(resource, {
                          user: current_user,
                          notes_limit: content_limit,
                          serializer: 'ai',
                          resource: self
                        })
      end

      def current_page_type
        "merge_request"
      end

      def current_page_short_description
        <<~SENTENCE
          The user is currently on a page that displays a merge request with a description, comments, etc., which the user might refer to, for example, as 'current', 'this' or 'that'. The title of the merge request is '#{resource.title}'.
        SENTENCE
      end
    end
  end
end
