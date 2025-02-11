# frozen_string_literal: true

module Resolvers
  module Issuables
    class CustomFieldsResolver < BaseResolver
      include LooksAhead

      type Types::Issuables::CustomFieldType.connection_type, null: true

      argument :active, GraphQL::Types::Boolean,
        required: false,
        description: 'Filter for active fields. If `false`, excludes active fields. ' \
          'If `true`, returns only active fields.'

      argument :search, GraphQL::Types::String,
        required: false,
        description: 'Search query for custom field name.'

      argument :work_item_type_ids, [Types::GlobalIDType[::WorkItems::Type]],
        required: false,
        description: 'Filter custom fields associated to the given work item types. ' \
          'If empty, returns custom fields not associated to any work item type.',
        prepare: ->(global_ids, _ctx) { global_ids.map(&:model_id) }

      def resolve_with_lookahead(active: nil, search: nil, work_item_type_ids: nil)
        correct_work_item_type_ids = work_item_type_ids_from(work_item_type_ids) unless work_item_type_ids.nil?

        custom_fields = ::Issuables::CustomFieldsFinder.new(
          current_user,
          group: object,
          active: active,
          search: search,
          work_item_type_ids: correct_work_item_type_ids
        ).execute

        offset_pagination(
          apply_lookahead(custom_fields)
        )
      end

      def unconditional_includes
        [:namespace]
      end

      def preloads
        {
          created_by: [:created_by],
          updated_by: [:updated_by],
          select_options: [:select_options],
          work_item_types: [:work_item_types]
        }
      end

      private

      def work_item_type_ids_from(request_ids)
        ::WorkItems::Type.with_correct_id_and_fallback(request_ids).map(&:correct_id)
      end
    end
  end
end
