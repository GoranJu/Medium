# frozen_string_literal: true

module Ai
  module AmazonQ
    class UpdateService < BaseService
      def execute
        return availability_param_error if availability_param_error

        success = application_settings.update(duo_availability: params[:availability])
        return ServiceResponse.error(message: application_settings.errors.full_messages.to_sentence) unless success

        create_audit_event(audit_availability: true, audit_ai_settings: false)
        result =
          if Ai::AmazonQ.should_block_service_account?(availability: params[:availability])
            Ai::AmazonQ.ensure_service_account_blocked!(current_user: user)
          else
            Ai::AmazonQ.ensure_service_account_unblocked!(current_user: user)
          end

        return result unless result.success?

        ServiceResponse.success
      end
    end
  end
end
