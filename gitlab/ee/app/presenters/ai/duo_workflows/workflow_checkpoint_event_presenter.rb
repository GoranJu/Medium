# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowCheckpointEventPresenter < Gitlab::View::Presenter::Delegated
      presents ::Ai::DuoWorkflows::Checkpoint, as: :event

      def timestamp
        Time.parse(event.thread_ts)
      end

      def parent_timestamp
        Time.parse(event.parent_ts) if event.parent_ts
      end

      def workflow_status
        event.workflow.status
      end

      def workflow_goal
        event.workflow.goal
      end

      def workflow_definition
        event.workflow.workflow_definition
      end
    end
  end
end
