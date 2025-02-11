# frozen_string_literal: true

module Types
  module MemberRoles
    # Anyone who can update group/project members can also read member roles
    # But it is too complex to be included on a simple MemberRole type
    #
    # rubocop: disable Graphql/AuthorizeTypes -- authorization too complex
    class MemberRoleType < BaseObject
      graphql_name 'MemberRole'
      description 'Represents a member role'

      include MemberRolesHelper

      implements Types::Members::RoleInterface

      field :base_access_level,
        Types::AccessLevelType,
        null: false,
        experiment: { milestone: '16.5' },
        description: 'Base access level for the custom role.'

      field :enabled_permissions,
        ::Types::Members::CustomizableStandardPermissionType.connection_type,
        null: false,
        experiment: { milestone: '16.5' },
        description: 'Array of all permissions enabled for the custom role.'

      field :edit_path,
        GraphQL::Types::String,
        null: false,
        experiment: { milestone: '16.11' },
        description: 'Web UI path to edit the custom role.'

      field :created_at,
        Types::TimeType,
        null: false,
        description: 'Timestamp of when the member role was created.'

      field :dependent_security_policies,
        [::Types::SecurityOrchestration::ApprovalPolicyType],
        null: true,
        description: 'Array of security policies dependent on the custom role.',
        resolver: ::Resolvers::Members::ApprovalPolicyResolver

      def members_count
        return object.members_count if object.respond_to?(:members_count)

        object.members.count
      end

      def users_count
        object.users_count if object.respond_to?(:users_count)

        object.users.count
      end

      def edit_path
        member_role_edit_path(object)
      end

      def details_path
        member_role_details_path(object)
      end
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
