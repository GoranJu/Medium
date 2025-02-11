# frozen_string_literal: true

module Gitlab
  module Auth
    module GroupSaml
      class DuoAddOnAssignmentUpdater
        include Gitlab::Utils::StrongMemoize

        attr_reader :user, :group, :auth_hash

        def initialize(user, group, auth_hash)
          @user = user
          @group = group
          @auth_hash = auth_hash
        end

        def execute
          return unless Feature.enabled?(:saml_groups_duo_add_on_assignment, group)
          return unless group_names_from_saml.any?
          return unless add_on_purchase&.active?

          if user_in_add_on_group?
            assign_duo_seat
          else
            unassign_duo_seat
          end
        end

        private

        def assign_duo_seat
          return if existing_add_on_assignment?

          ::GitlabSubscriptions::AddOnPurchases::CreateUserAddOnAssignmentWorker.perform_async(user.id, group.id)
        end

        def unassign_duo_seat
          return unless existing_add_on_assignment?

          ::GitlabSubscriptions::AddOnPurchases::DestroyUserAddOnAssignmentWorker.perform_async(user.id, group.id)
        end

        def group_names_from_saml
          auth_hash.groups || []
        end
        strong_memoize_attr :group_names_from_saml

        def duo_groups
          SamlGroupLink
            .by_saml_group_name(group_names_from_saml)
            .by_group_id(group.id)
            .by_assign_duo_seats(true)
        end
        strong_memoize_attr :duo_groups

        def user_in_add_on_group?
          duo_groups.exists?
        end

        def add_on_purchase
          ::GitlabSubscriptions::Duo.enterprise_or_pro_for_namespace(group)
        end
        strong_memoize_attr :add_on_purchase

        def existing_add_on_assignment?
          user.assigned_add_ons.for_active_add_on_purchase_ids(add_on_purchase.id).any?
        end
        strong_memoize_attr :existing_add_on_assignment?
      end
    end
  end
end
