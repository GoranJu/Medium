# frozen_string_literal: true

module Ai
  module AmazonQ
    class ServiceAccountMemberAddService
      def initialize(project)
        @project = project
      end

      def execute
        existing_member = project.member(service_account_user)
        return ServiceResponse.success(message: "Membership already exists. Nothing to do.") if existing_member

        return ServiceResponse.error(message: "Service account user not found") unless service_account_user

        result = project.add_developer(service_account_user)
        ServiceResponse.success(payload: result)
      end

      private

      attr_reader :project

      def service_account_user
        Ai::Setting.instance.amazon_q_service_account_user
      end
    end
  end
end
