# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    module ComplianceRequirements
      class UpdateService < BaseService
        attr_reader :params, :current_user, :requirement

        def initialize(requirement:, params:, current_user:)
          @requirement = requirement
          @params = params
          @current_user = current_user
        end

        def execute
          return ServiceResponse.error(message: _('Not permitted to update requirement')) unless permitted?

          return error unless requirement.update(params)

          audit_changes
          success
        end

        private

        def permitted?
          can? current_user, :admin_compliance_framework, requirement.framework
        end

        def success
          ServiceResponse.success(payload: { requirement: requirement })
        end

        def audit_changes
          requirement.previous_changes.each do |attribute, changes|
            next if attribute.eql?('updated_at')

            audit_context = {
              name: 'update_compliance_requirement',
              author: current_user,
              scope: requirement.framework.namespace,
              target: requirement,
              message: "Changed compliance requirement's #{attribute} from #{changes[0]} to #{changes[1]}"
            }

            ::Gitlab::Audit::Auditor.audit(audit_context)
          end
        end

        def error
          ServiceResponse.error(message: _('Failed to update compliance requirement'), payload: requirement.errors)
        end
      end
    end
  end
end
