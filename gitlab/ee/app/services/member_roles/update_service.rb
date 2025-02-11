# frozen_string_literal: true

module MemberRoles
  class UpdateService < BaseService
    def execute(member_role)
      @member_role = member_role

      return authorized_error unless allowed?

      update_member_role
    end

    private

    def update_member_role
      member_role.assign_attributes(params.slice(:name, :description, *MemberRole.all_customizable_permissions.keys))

      if member_role.save
        log_audit_event(member_role, action: :updated)

        ::ServiceResponse.success(payload: { member_role: member_role })
      else
        ::ServiceResponse.error(message: member_role.errors.full_messages, payload: { member_role: member_role.reset })
      end
    end
  end
end
