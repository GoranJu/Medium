# frozen_string_literal: true

module Ai
  module AiResource
    module Ci
      class Build < Ai::AiResource::BaseAiResource
        include Ai::AiResource::Concerns::Noteable

        def serialize_for_ai(content_limit:)
          ::Ci::JobSerializer # rubocop: disable CodeReuse/Serializer -- existing serializer
            .new(current_user: current_user)
            .represent(resource, {
              user: current_user,
              content_limit: content_limit,
              resource: self
            }, ::Ci::JobAiEntity)
        end

        def current_page_type
          "build"
        end

        def current_page_short_description
          <<~SENTENCE
          The user is currently on a page that displays a ci build which the user might refer to, for example, as 'current', 'this' or 'that'.
          SENTENCE
        end

        def current_page_params
          {
            type: current_page_type
          }
        end
      end
    end
  end
end
