# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    module ComplianceRequirements
      class CreateService < BaseService
        attr_reader :params, :current_user, :framework, :requirement

        def initialize(framework:, params:, current_user:)
          @framework = framework
          @params = params
          @current_user = current_user
          @requirement = ComplianceManagement::ComplianceFramework::ComplianceRequirement.new
        end

        def execute
          requirement.assign_attributes(
            framework: framework,
            namespace_id: framework.namespace.id,
            name: params[:name],
            description: params[:description],
            control_expression: params[:control_expression]
          )

          return ServiceResponse.error(message: 'Not permitted to create requirement') unless permitted?

          return error unless requirement.save

          audit_create
          success
        end

        private

        def permitted?
          can? current_user, :admin_compliance_framework, framework
        end

        def success
          ServiceResponse.success(payload: { requirement: requirement })
        end

        def audit_create
          audit_context = {
            name: 'created_compliance_requirement',
            author: current_user,
            scope: framework.namespace,
            target: requirement,
            message: "Created compliance requirement #{requirement.name} for framework #{framework.name}"
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def error
          ServiceResponse.error(message: _('Failed to create compliance requirement'), payload: requirement.errors)
        end
      end
    end
  end
end
