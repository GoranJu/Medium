# frozen_string_literal: true

module Search
  module Zoekt
    class TaskPresenterService
      include Gitlab::Loggable

      attr_reader :node, :concurrency_limit

      def self.execute(...)
        new(...).execute
      end

      def initialize(node)
        @node = node
        @concurrency_limit = node.concurrency_limit
      end

      def execute
        return [] if ::Gitlab::CurrentSettings.zoekt_indexing_paused?

        [].tap do |payload|
          tasks.each_task_for_processing(limit: concurrency_limit) do |task|
            payload << TaskSerializerService.execute(task)
          end
        end
      end

      private

      def tasks
        if node.watermark_exceeded_critical?
          logger.warn(build_structured_payload(
            message: 'Node watermark exceeded critical threshold. Only presenting delete tasks',
            meta: node.metadata_json
          ))

          node.tasks.delete_repo
        else
          node.tasks
        end
      end

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end
    end
  end
end
