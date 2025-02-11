# frozen_string_literal: true

module Search
  module Zoekt
    class Task < ApplicationRecord
      include PartitionedTable
      include EachBatch
      include BulkInsertSafe

      PARTITION_DURATION = 1.day
      PARTITION_CLEANUP_THRESHOLD = 7.days
      PROCESSING_BATCH_SIZE = 100

      self.table_name = 'zoekt_tasks'
      self.primary_key = :id

      ignore_column :partition_id, remove_never: true
      attribute :retries_left, default: 3

      belongs_to :node, foreign_key: :zoekt_node_id, inverse_of: :tasks, class_name: '::Search::Zoekt::Node'
      belongs_to :zoekt_repository, inverse_of: :tasks, class_name: '::Search::Zoekt::Repository'

      before_validation :set_project_identifier

      scope :for_partition, ->(partition) { where(partition_id: partition) }
      scope :with_project, -> { includes(zoekt_repository: :project) }
      scope :join_nodes, -> { joins(:node) }
      scope :perform_now, -> { where(perform_at: (..Time.zone.now)) }
      scope :pending_or_processing, -> { where(state: %i[pending processing]) }
      scope :processing_queue, -> { perform_now.pending_or_processing }

      enum state: {
        pending: 0,
        processing: 1,
        done: 10,
        skipped: 250,
        failed: 255,
        orphaned: 256
      }

      enum task_type: {
        index_repo: 0,
        force_index_repo: 1,
        delete_repo: 50
      }

      partitioned_by :partition_id,
        strategy: :sliding_list,
        next_partition_if: ->(active_partition) { next_partition?(active_partition) },
        detach_partition_if: ->(partition) { detach_partition?(partition) }

      def self.next_partition?(active_partition)
        oldest_record_in_partition = Task
          .select(:id, :created_at)
          .for_partition(active_partition.value)
          .order(:id)
          .first

        oldest_record_in_partition.present? && oldest_record_in_partition.created_at < PARTITION_DURATION.ago
      end

      def self.detach_partition?(partition)
        newest_task_older(partition, PARTITION_CLEANUP_THRESHOLD) && no_pending_or_processing(partition)
      end

      def self.newest_task_older(partition, duration)
        newest_record = Task.select(:id, :created_at).for_partition(partition.value).order(:id).last
        return true if newest_record.nil?

        newest_record.created_at < duration.ago
      end

      def self.no_pending_or_processing(partition)
        !Task.for_partition(partition.value).join_nodes.pending_or_processing.exists?
      end

      def self.each_task_for_processing(limit:)
        return unless block_given?

        count = 0

        scope = processing_queue.with_project.order(:perform_at, :id)
        iterator = Gitlab::Pagination::Keyset::Iterator.new(scope: scope)
        processed_project_identifiers = Set.new
        iterator.each_batch(of: PROCESSING_BATCH_SIZE) do |tasks|
          orphaned_task_ids = []
          skipped_task_ids = []

          tasks.each do |task|
            unless task.delete_repo?
              unless task.zoekt_repository&.project
                orphaned_task_ids << task.id
                next
              end

              if task.zoekt_repository.failed?
                skipped_task_ids << task.id
                next
              end
            end

            next unless processed_project_identifiers.add?(task.project_identifier)

            yield task
            count += 1
            break if count >= limit
          end

          tasks.where(id: orphaned_task_ids).update_all(state: :orphaned) if orphaned_task_ids.any?
          tasks.where(id: skipped_task_ids).update_all(state: :skipped) if skipped_task_ids.any?
          tasks.where.not(state: [:orphaned, :skipped]).update_all(state: :processing)

          break if count >= limit
        end
      end

      private

      def set_project_identifier
        self.project_identifier ||= zoekt_repository&.project_identifier
      end
    end
  end
end
