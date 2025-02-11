# frozen_string_literal: true

module Ai
  module SelfHostedModels
    class UpdateService
      def initialize(self_hosted_model, user, update_params)
        @self_hosted_model = self_hosted_model
        @user = user
        @params = update_params
      end

      def execute
        if self_hosted_model.update(params)
          record_audit_event

          ServiceResponse.success(payload: self_hosted_model)
        else
          ServiceResponse.error(message: self_hosted_model.errors.full_messages.join(", "))
        end
      end

      private

      attr_accessor :self_hosted_model, :user, :params

      def record_audit_event
        model = self_hosted_model
        audit_context = {
          name: 'self_hosted_model_updated',
          author: user,
          scope: Gitlab::Audit::InstanceScope.new,
          target: model,
          message: "Self-hosted model #{model.name}/#{model.model}/#{model.endpoint} updated"
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
