# frozen_string_literal: true

module Types
  module MemberRoles
    # rubocop: disable Graphql/AuthorizeTypes
    class CustomizablePermissionType < BaseObject
      graphql_name 'CustomizablePermission'

      include Gitlab::Utils::StrongMemoize

      field :available_for,
        type: [GraphQL::Types::String],
        null: false,
        description: 'Objects the permission is available for.'

      field :description,
        type: GraphQL::Types::String,
        null: true,
        description: 'Description of the permission.'

      field :name,
        type: GraphQL::Types::String,
        null: false,
        description: 'Localized name of the permission.'

      field :requirements,
        type: [Types::MemberRoles::PermissionsEnum],
        null: true,
        description: 'Requirements of the permission.'

      field :value,
        type: Types::MemberRoles::PermissionsEnum,
        null: false,
        description: 'Value of the permission.',
        method: :itself

      field :available_from_access_level,
        type: Types::AccessLevelType,
        null: true,
        description: 'Access level from which the permission is available.'

      field :enabled_for_group_access_levels,
        type: [Types::AccessLevelEnum],
        null: true,
        description: 'Group access levels from which the permission is allowed.'

      field :enabled_for_project_access_levels,
        type: [Types::AccessLevelEnum],
        null: true,
        description: 'Project access levels from which the permission is allowed.'

      def available_for
        result = []
        result << :project if MemberRole.all_customizable_project_permissions.include?(object)
        result << :group if MemberRole.all_customizable_group_permissions.include?(object)

        result
      end

      def description
        _(permission[:description])
      end

      def name
        permission[:title] || object.to_s.humanize
      end

      def requirements
        permission[:requirements].presence&.map(&:to_sym)
      end

      def available_from_access_level
        permission[:available_from_access_level]
      end

      def enabled_for_group_access_levels
        permission[:enabled_for_group_access_levels]
      end

      def enabled_for_project_access_levels
        permission[:enabled_for_project_access_levels]
      end

      def permission
        MemberRole.all_customizable_permissions[object]
      end
      strong_memoize_attr :permission
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
