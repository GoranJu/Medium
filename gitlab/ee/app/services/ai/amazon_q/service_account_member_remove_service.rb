# frozen_string_literal: true

module Ai
  module AmazonQ
    class ServiceAccountMemberRemoveService
      def initialize(user, membership_container)
        @user = user
        @membership_container = membership_container
      end

      def execute
        member = find_or_initialize_member_by_user

        return ServiceResponse.success(message: "Membership not found. Nothing to do.") unless member

        Members::DestroyService.new(user).execute(
          member,
          skip_authorization: true,
          skip_subresources: false,
          unassign_issuables: false
        )

        ServiceResponse.success
      end

      private

      attr_reader :user, :membership_container

      def find_or_initialize_member_by_user
        existing_member = membership_container.member(service_account_user)

        return existing_member unless membership_container.is_a?(Group) && !existing_member

        # build a membership so we can run destroy service on subresources
        membership_container.members.build(user: service_account_user)
      end

      def service_account_user
        Ai::Setting.instance.amazon_q_service_account_user
      end
    end
  end
end
