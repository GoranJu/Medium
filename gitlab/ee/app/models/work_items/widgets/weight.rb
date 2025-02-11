# frozen_string_literal: true

module WorkItems
  module Widgets
    class Weight < Base
      include Gitlab::Utils::StrongMemoize

      def self.quick_action_commands
        [:weight, :clear_weight]
      end

      def self.quick_action_params
        [:weight]
      end

      def weight
        return unless widget_options[:editable]

        work_item.weight
      end

      def rolled_up_weight
        return unless widget_options[:rollup] && rolled_up_weight_by_state.present?

        rolled_up_weight_by_state.sum { |_, weight| weight }
      end

      def rolled_up_completed_weight
        return unless widget_options[:rollup] && rolled_up_weight_by_state.present?

        rolled_up_weight_by_state.fetch(WorkItem.available_states[:closed], 0)
      end

      private

      def rolled_up_weight_by_state
        # We cannot use `#sum(:weight)` because ActiveRecord returns 0 when PG returns NULL.
        # We need to distinguish between a sum of 0 and the absence of descendant weights.
        work_item.descendants
          .where(correct_work_item_type_id: WorkItems::Type.default_issue_type.correct_id)
          .group(:state_id)
          .pluck('state_id, SUM(weight)') # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- We only have a limited number of states
          .to_h
          .compact
      end
      strong_memoize_attr :rolled_up_weight_by_state
    end
  end
end
