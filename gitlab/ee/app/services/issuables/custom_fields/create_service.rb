# frozen_string_literal: true

module Issuables
  module CustomFields
    class CreateService < BaseGroupService
      FeatureNotAvailableError = ServiceResponse.error(
        message: 'This feature is currently behind a feature flag and it is not available.'
      )
      NotAuthorizedError = ServiceResponse.error(
        message: "You don't have permissions to create a custom field for this group."
      )

      def execute
        return FeatureNotAvailableError unless Feature.enabled?('custom_fields_feature', group)
        return NotAuthorizedError unless can?(current_user, :admin_custom_field, group)

        custom_field = Issuables::CustomField.new(
          namespace: group,
          created_by: current_user
        )

        custom_field.assign_attributes(params.slice(:field_type, :name, :work_item_type_ids))
        handle_select_options(custom_field)

        if custom_field.save
          custom_field.reset_ordered_associations

          ServiceResponse.success(payload: { custom_field: custom_field })
        else
          ServiceResponse.error(message: custom_field.errors.full_messages)
        end
      end

      private

      def handle_select_options(custom_field)
        return unless params[:select_options]

        params[:select_options].each_with_index do |option, i|
          custom_field.select_options.build(value: option[:value], position: i)
        end
      end
    end
  end
end
