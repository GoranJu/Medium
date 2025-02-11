# frozen_string_literal: true

module EE
  module Mutations
    module WorkItems
      module BulkUpdate
        extend ::Gitlab::Utils::Override

        private

        override :parent_for!
        def parent_for!(parent_id)
          parent = super
          return parent unless parent.is_a?(::Group)

          unless parent.licensed_feature_available?(:group_bulk_edit)
            raise_resource_not_available_error!(
              _('Group work item bulk edit is a licensed feature not available for this group.')
            )
          end

          parent
        end
      end
    end
  end
end
