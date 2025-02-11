# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- TODO refactor to use bounded context
module AutoMerge
  module MergeTrains
    class BaseService < ::AutoMerge::BaseService
      AvailabilityCheck = Struct.new(:unavailable_reason, :unsuccessful_check) do
        def available?
          unavailable_reason.nil?
        end
      end

      def available_for?(merge_request)
        strong_memoize("available_for_#{merge_request.id}") do
          availability_details(merge_request).available?
        end
      end

      private

      def availability_details(merge_request)
        strong_memoize("availability_details_#{merge_request.id}") do
          unless merge_request.can_be_merged_by?(current_user)
            next AvailabilityCheck.new(unavailable_reason: :forbidden)
          end

          mergeability_checks = merge_request.execute_merge_checks(
            MergeRequest.all_mergeability_checks,
            params: skippable_available_for_checks(merge_request),
            execute_all: false
          )

          unless mergeability_checks.success?
            next AvailabilityCheck.new(unavailable_reason: :mergeability_checks_failed,
              unsuccessful_check: mergeability_checks.payload[:unsuccessful_check])
          end

          yield
        end
      end

      def process_abort_message(availability_details)
        abort_messages = {
          forbidden: 'they do not have permission to merge the merge request.',
          mergeability_checks_failed: "the merge request cannot be merged. Failed mergeability check: " \
            "#{availability_details.unsuccessful_check || 'unknown'}",
          merge_trains_disabled: 'merge trains are disabled for this project.',
          missing_diff_head_pipeline: 'the pipeline associated with this merge request is missing or out of sync.',
          incomplete_diff_head_pipeline: 'the merge request currently has a pipeline in progress.',
          default: 'this merge request cannot be added to the merge train.'
        }

        abort_messages[availability_details.unavailable_reason] || abort_messages[:default]
      end
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts
