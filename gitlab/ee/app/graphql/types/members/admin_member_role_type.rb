# frozen_string_literal: true

module Types
  module Members
    class AdminMemberRoleType < Types::MemberRoles::MemberRoleType
      graphql_name 'AdminMemberRole'
      description 'Represents an admin member role'

      authorize :admin_member_role

      field :enabled_permissions,
        ::Types::Members::CustomizableAdminPermissionType.connection_type,
        null: false,
        experiment: { milestone: '17.7' },
        description: 'Array of all permissions enabled for the custom role.'
    end
  end
end
