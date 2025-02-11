# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class Checkpoint < ::ApplicationRecord
      self.table_name = :duo_workflows_checkpoints

      belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'
      belongs_to :project

      # checkpoint_writes can be created independently on checkpoints by langgraph so checkpoints and checkpoint_writes
      # are associated only by langgraph's thread_ts
      has_many :checkpoint_writes, ->(checkpoint) { where(workflow_id: checkpoint.workflow_id) },
        foreign_key: :thread_ts, primary_key: :thread_ts, inverse_of: :checkpoint

      validates :thread_ts, presence: true
      validates :checkpoint, presence: true
      validates :metadata, presence: true

      after_save :touch_workflow

      scope :ordered_with_writes, -> { includes(:checkpoint_writes).order(thread_ts: :desc) }

      private

      def touch_workflow
        workflow.touch
      end
    end
  end
end
