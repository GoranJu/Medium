# frozen_string_literal: true

module Gitlab
  module EpicWorkItemSync
    class BulkVerification
      BATCH_SIZE = 1000

      def initialize(filter_attributes:)
        @filtered_attributes = filter_attributes.index_with { true }
      end

      def verify
        verifications = { valid: 0, mismatched: 0 }

        preloaded_epics.each_batch(of: BATCH_SIZE) do |epics|
          epics.each do |epic|
            mismatches = filtered_mismatches(epic)

            if mismatches.any?
              log_mismatch(epic, mismatches)
              verifications[:mismatched] += 1
            else
              verifications[:valid] += 1
            end
          end

          yield verifications if block_given?
        end

        verifications
      end

      private

      attr_reader :filtered_attributes

      def filtered_mismatches(epic)
        Diff.new(epic, epic.work_item).attributes.select { |attr| filtered_attributes[attr] }
      end

      def log_mismatch(epic, mismatched_attributes)
        Logger.warn(
          epic_id: epic.id,
          work_item_id: epic.issue_id,
          mismatching_attributes: mismatched_attributes
        )
      end

      def preloaded_epics
        # rubocop:disable CodeReuse/ActiveRecord -- we want to preload to save us queries
        Epic.with_work_item.preload(:epic_issues, work_item: [:dates_source, :child_links, :work_item_parent, :color])
        # rubocop:enable CodeReuse/ActiveRecord
      end
    end
  end
end
