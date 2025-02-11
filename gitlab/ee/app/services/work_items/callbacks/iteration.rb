# frozen_string_literal: true

module WorkItems
  module Callbacks
    class Iteration < Base
      def before_create
        handle_iteration_change
      end

      def before_update
        params[:iteration] = nil if excluded_in_new_type?

        handle_iteration_change
      end

      private

      def handle_iteration_change
        return unless params.present? && params.key?(:iteration)
        return unless has_permission?(:admin_work_item)

        if params[:iteration].nil?
          work_item.iteration = nil

          return
        end

        return unless in_the_same_group_hierarchy?(params[:iteration])

        work_item.iteration = params[:iteration]
      end

      def in_the_same_group_hierarchy?(iteration)
        group_ids = (work_item.project&.group || work_item.namespace).self_and_ancestors.select(:id)

        ::Iteration.of_groups(group_ids).id_in(iteration.id).exists?
      end
    end
  end
end
