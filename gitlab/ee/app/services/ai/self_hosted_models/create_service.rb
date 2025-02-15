# frozen_string_literal: true

module Ai
  module SelfHostedModels
    class CreateService
      def initialize(current_user, params)
        @params = params
        @user = current_user
      end

      def execute
        @self_hosted_model = ::Ai::SelfHostedModel.new(params)

        if @self_hosted_model.save
          audit_creation_event(@self_hosted_model)

          ServiceResponse.success(payload: @self_hosted_model)
        else
          ServiceResponse.error(message: @self_hosted_model.errors.full_messages.join(", "))
        end
      end

      private

      def audit_creation_event(model)
        audit_context = {
          name: 'self_hosted_model_created',
          author: user,
          scope: Gitlab::Audit::InstanceScope.new,
          target: model,
          message: "Self-hosted model #{model.name}/#{model.model}/#{model.endpoint} created"
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      attr_accessor :user, :params
    end
  end
end
