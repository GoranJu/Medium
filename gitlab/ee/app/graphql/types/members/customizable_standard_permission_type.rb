# frozen_string_literal: true

module Types
  module Members
    # rubocop: disable Graphql/AuthorizeTypes -- globally available
    class CustomizableStandardPermissionType < ::Types::MemberRoles::CustomizablePermissionType
      graphql_name 'CustomizableStandardPermission'

      field :requirements,
        type: [Types::Members::CustomizableStandardPermissionsEnum],
        null: true,
        description: 'Requirements of the permission.'

      field :value,
        type: Types::Members::CustomizableStandardPermissionsEnum,
        null: false,
        description: 'Value of the permission.',
        method: :itself

      def permission
        MemberRole.all_customizable_standard_permissions[object]
      end
      strong_memoize_attr :permission
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
