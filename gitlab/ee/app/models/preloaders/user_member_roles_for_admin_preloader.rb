# frozen_string_literal: true

module Preloaders
  class UserMemberRolesForAdminPreloader
    include Gitlab::Utils::StrongMemoize

    def initialize(user:)
      @user = user
    end

    def execute
      ::Gitlab::SafeRequestLoader.execute(
        resource_key: resource_key,
        resource_ids: [:admin]
      ) do
        admin_abilities_for_user
      end
    end

    private

    def admin_abilities_for_user
      user_member_roles = Users::UserMemberRole.where(user_id: user.id).includes(:member_role)
      user_abilities = user_member_roles.flat_map do |user_role|
        user_role.member_role.enabled_permissions
      end

      { admin: user_abilities & enabled_permissions }
    end

    def resource_key
      "member_roles_for_admin:user:#{user.id}"
    end

    def enabled_permissions
      MemberRole
        .all_customizable_admin_permission_keys
        .filter { |permission| ::MemberRole.permission_enabled?(permission, user) }
    end
    strong_memoize_attr :enabled_permissions

    attr_reader :user
  end
end
