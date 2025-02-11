# frozen_string_literal: true

module GitlabSubscriptions
  module BillableUsersUtils
    include ::GitlabSubscriptions::SubscriptionHelper
    include Gitlab::Utils::StrongMemoize

    InvalidSubscriptionTypeError = Class.new(StandardError)

    # if not Ultimate
    # returns true for all roles besides NO_ACCESS
    # if Ultimate
    # returns true for all roles > GUEST
    # returns true if role = GUEST and member_role_id corresponds to elevated member_role
    # returns true if role = MINIMAL_ACCESS with any member_role
    def sm_billable_role_change?(role:, member_role_id: nil)
      ensure_feature_enabled!

      raise InvalidSubscriptionTypeError if gitlab_com_subscription?

      return true if role > Gitlab::Access::GUEST
      return false if role == Gitlab::Access::NO_ACCESS

      return true unless License.current&.exclude_guests_from_active_count?

      return minimal_access_billable?(member_role_id) if role == Gitlab::Access::MINIMAL_ACCESS

      member_role_billable?(member_role_id)
    end

    # if not Ultimate
    # returns false for NO_ACCESS and (MINIMAL_ACCESS without member_role_id)
    # returns true otherwise
    # if Ultimate
    # returns true for all roles > GUEST
    # returns true if role = GUEST and member_role_id corresponds to elevated member_role
    # returns true if role = MINIMAL_ACCESS with any member_role
    def saas_billable_role_change?(target_namespace:, role:, member_role_id: nil)
      ensure_feature_enabled!

      raise InvalidSubscriptionTypeError unless gitlab_com_subscription?

      return true if role > Gitlab::Access::GUEST
      return false if role == Gitlab::Access::NO_ACCESS
      return minimal_access_billable?(member_role_id) if role == Gitlab::Access::MINIMAL_ACCESS

      return true unless target_namespace&.exclude_guests?

      member_role_billable?(member_role_id)
    end

    private

    def ensure_feature_enabled!
      return if ::Feature.enabled?(:member_promotion_management, type: :beta)

      raise "Attempted to use a WIP feature that is not enabled!"
    end

    def minimal_access_billable?(member_role_id)
      member_role_id.present? && valid_member_role(member_role_id).present?
    end

    def member_role_billable?(member_role_id)
      return false unless member_role_id

      member_role = valid_member_role(member_role_id)

      return false unless member_role

      (MemberRole.elevating_permissions & member_role.enabled_permissions).present?
    end

    def valid_member_role(member_role_id)
      strong_memoize_with(:valid_member_role, member_role_id) do
        MemberRole.find_by_id(member_role_id)
      end
    end
  end
end
