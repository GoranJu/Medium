# frozen_string_literal: true

module MemberRoles
  class BaseService < ::BaseService
    include Gitlab::Allowable

    def initialize(current_user, params = {})
      @current_user = current_user
      @params = params
    end

    private

    attr_accessor :current_user, :params, :member_role

    def allowed?
      can?(current_user, :admin_member_role, member_role)
    end

    def authorized_error
      ::ServiceResponse.error(message: _('Operation not allowed'), reason: :unauthorized)
    end

    def group
      params[:namespace] || member_role&.namespace
    end

    def log_audit_event(member_role, action:)
      audit_context = {
        name: "member_role_#{action}",
        author: current_user,
        scope: audit_event_scope,
        target: member_role,
        target_details: {
          name: member_role.name,
          description: member_role.description,
          abilities: member_role.enabled_permissions.join(', ')
        },
        message: "Member role was #{action}"
      }

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end

    def audit_event_scope
      group || Gitlab::Audit::InstanceScope.new
    end
  end
end
