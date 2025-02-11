# frozen_string_literal: true

module Mutations
  module MemberRoles
    class Update < Base
      graphql_name 'MemberRoleUpdate'

      argument :id, ::Types::GlobalIDType[::MemberRole],
        required: true,
        description: 'ID of the member role to mutate.'

      def ready?(**args)
        if args.except(:id).blank?
          raise Gitlab::Graphql::Errors::ArgumentError, 'The list of member_role attributes is empty'
        end

        super
      end

      def resolve(**args)
        member_role = authorized_find!(id: args.delete(:id))

        params = canonicalize(args)
        response = ::MemberRoles::UpdateService.new(current_user, params).execute(member_role)

        {
          member_role: response.payload[:member_role],
          errors: response.errors
        }
      end

      private

      def canonicalize(args)
        permissions = args.delete(:permissions)
        return args if permissions.nil?

        available_permissions = MemberRole.all_customizable_permissions.keys

        set_permissions(args, permissions & available_permissions, true)
        set_permissions(args, available_permissions - permissions, false)
      end

      def set_permissions(args, permissions, value)
        permissions.each_with_object(args) do |permission, new_args|
          new_args[permission] = value
        end
      end
    end
  end
end
