# frozen_string_literal: true

module Ai
  module AmazonQ
    class DestroyService < BaseService
      def execute
        result = block_service_account!

        return result unless result.success?

        destroy_oauth_application!

        if ai_settings.update(
          amazon_q_oauth_application_id: nil,
          amazon_q_ready: false,
          amazon_q_role_arn: nil
        )
          create_audit_event(
            audit_availability: false,
            audit_ai_settings: true,
            exclude_columns: %w[amazon_q_service_account_user_id]
          )
          ServiceResponse.success
        else
          ServiceResponse.error(message: ai_settings.errors.full_messages.to_sentence)
        end
      end

      private

      attr_reader :user

      def destroy_oauth_application!
        oauth_application = Doorkeeper::Application.find_by_id(ai_settings.amazon_q_oauth_application_id)
        oauth_application&.destroy!
      end

      def block_service_account!
        Ai::AmazonQ.ensure_service_account_blocked!(current_user: user)
      end
    end
  end
end
