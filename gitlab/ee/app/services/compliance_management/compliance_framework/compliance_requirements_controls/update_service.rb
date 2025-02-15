# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    module ComplianceRequirementsControls
      class UpdateService < BaseService
        def initialize(control:, params:, current_user:)
          @control = control
          super(nil, current_user, params)
        end

        def execute
          return ServiceResponse.error(message: _('Not permitted to update requirement control')) unless permitted?

          return error(control.errors.full_messages.join(', ')) unless control.update(params)

          audit_changes
          success
        rescue ArgumentError => e
          error(e.message)
        end

        private

        attr_reader :control

        def permitted?
          can? current_user, :admin_compliance_framework, control.compliance_requirement.framework
        end

        def audit_changes
          control.previous_changes.each do |attribute, changes|
            next if attribute.eql?('updated_at')

            audit_context = {
              name: 'updated_compliance_requirement_control',
              author: current_user,
              scope: control.namespace,
              target: control,
              message: "Changed compliance requirement control's #{attribute} from '#{changes[0]}' to '#{changes[1]}'"
            }

            ::Gitlab::Audit::Auditor.audit(audit_context)
          end
        end

        def success
          ServiceResponse.success(payload: { control: control })
        end

        def error(error_message)
          ServiceResponse.error(
            message: format(_("Failed to update compliance requirement control. Error: %{error_message}"),
              error_message: error_message))
        end
      end
    end
  end
end
