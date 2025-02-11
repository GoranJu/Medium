# frozen_string_literal: true

module Mutations
  module MemberRoles
    class CreateAdmin < Base
      graphql_name 'MemberRoleAdminCreate'

      include ::GitlabSubscriptions::SubscriptionHelper

      argument :permissions,
        [Types::Members::CustomizableAdminPermissionsEnum],
        required: true,
        description: 'List of all customizable admin permissions.'

      field :member_role, ::Types::Members::AdminMemberRoleType,
        description: 'Created member role.', null: true

      def ready?(**args)
        if gitlab_com_subscription?
          raise Gitlab::Graphql::Errors::ArgumentError, 'admin member roles are not available on SaaS instance.'
        end

        raise_resource_not_available_error! unless Feature.enabled?(:custom_ability_read_admin_dashboard, current_user)

        super
      end

      def resolve(**args)
        response = ::MemberRoles::CreateService.new(current_user, canonicalize(args)).execute

        raise_resource_not_available_error! if response.error? && response.reason == :unauthorized

        {
          member_role: response.payload[:member_role],
          errors: response.errors
        }
      end

      private

      def canonicalize(args)
        permissions = args.delete(:permissions) || []
        permissions.each_with_object(args) do |permission, new_args|
          new_args[permission.downcase] = true
        end
      end
    end
  end
end
