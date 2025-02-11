# frozen_string_literal: true

module Ai
  module AiResource
    class BaseAiResource
      attr_reader :resource, :current_user

      def initialize(user, resource)
        @resource = resource
        @current_user = user
      end

      def serialize_for_ai(_content_limit:)
        raise NotImplementedError
      end

      def current_page_params
        {
          type: current_page_type,
          title: resource.title
        }
      end

      def current_page_type
        raise NotImplementedError
      end
    end
  end
end
