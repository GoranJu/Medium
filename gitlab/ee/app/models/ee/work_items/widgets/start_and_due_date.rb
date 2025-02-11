# frozen_string_literal: true

module EE
  module WorkItems
    module Widgets
      module StartAndDueDate
        include ::Gitlab::Utils::StrongMemoize
        extend ::Gitlab::Utils::Override
        extend ActiveSupport::Concern

        class_methods do
          def sync_params
            %i[start_date_fixed start_date_is_fixed due_date_fixed due_date_is_fixed]
          end
        end

        def start_date
          return super if fixed?
          return work_item&.start_date unless dates_source_present?

          dates_source.start_date
        end

        def start_date_sourcing_work_item
          return if fixed?

          dates_source.start_date_sourcing_work_item
        end

        def start_date_sourcing_milestone
          return if fixed?

          dates_source.start_date_sourcing_milestone
        end

        def due_date
          return super if fixed?
          return work_item&.due_date unless dates_source_present?

          dates_source.due_date
        end

        def due_date_sourcing_work_item
          return if fixed?

          dates_source.due_date_sourcing_work_item
        end

        def due_date_sourcing_milestone
          return if fixed?

          dates_source.due_date_sourcing_milestone
        end

        override :fixed?
        def fixed?
          return true unless can_rollup?
          return true if dates_source.start_date_is_fixed && dates_source.start_date_fixed.present?
          return true if dates_source.due_date_is_fixed && dates_source.due_date_fixed.present?

          dates_source.start_date_is_fixed && dates_source.due_date_is_fixed
        end
        strong_memoize_attr :fixed?

        override :can_rollup?
        def can_rollup?
          work_item&.work_item_type&.allowed_child_types.present?
        end
        strong_memoize_attr :can_rollup?
      end
    end
  end
end
