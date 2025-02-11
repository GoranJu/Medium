# frozen_string_literal: true

module EE
  module PersonalAccessTokenPolicy # rubocop:disable Gitlab/BoundedContexts -- Existing policy with EE extension.
    extend ActiveSupport::Concern

    prepended do
      condition(:is_enterprise_user_manager) { user && subject.user.managed_by_user?(user) }
      condition(:group_credentials_inventory_available) do
        ::Gitlab::Saas.feature_available?(:group_credentials_inventory) &&
          subject.user.enterprise_group&.licensed_feature_available?(:credentials_inventory)
      end

      rule { is_enterprise_user_manager & group_credentials_inventory_available }.policy do
        enable :revoke_token
      end
    end
  end
end
