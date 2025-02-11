# frozen_string_literal: true

module Mutations
  module MemberRoles
    class Base < ::Mutations::BaseMutation
      authorize :admin_member_role

      field :member_role, ::Types::MemberRoles::MemberRoleType,
        description: 'Updated member role.', null: true

      argument :description,
        GraphQL::Types::String,
        required: false,
        description: 'Description of the member role.'
      argument :name,
        GraphQL::Types::String,
        required: false,
        description: 'Name of the member role.'
      argument :permissions,
        [Types::MemberRoles::PermissionsEnum],
        required: false,
        description: 'List of all customizable permissions.'
    end
  end
end
