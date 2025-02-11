# frozen_string_literal: true

module Ai
  module Conversation
    class CleanupService
      def execute
        Ai::Conversation::Thread.expired.each_batch do |relation|
          relation.delete_all
        end
      end
    end
  end
end
