# frozen_string_literal: true

module EE
  module Groups
    module GroupLinks
      module CreateService
        extend ::Gitlab::Utils::Override
        include GroupLinksHelper

        override :valid_to_create?
        def valid_to_create?
          super && !member_role_too_high?
        end

        override :after_successful_save
        def after_successful_save
          super

          log_audit_event
        end

        private

        override :remove_unallowed_params
        def remove_unallowed_params
          params.delete(:member_role_id) unless custom_role_for_group_link_enabled?(group)

          super
        end

        def log_audit_event
          audit_context = {
            name: "group_share_with_group_link_created",
            author: current_user,
            scope: link.shared_group,
            target: link.shared_with_group,
            stream_only: false,
            message: "Invited #{link.shared_with_group.name} " \
                     "to the group #{link.shared_group.name}"
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def member_role_too_high?
          group.assigning_role_too_high?(current_user, params[:shared_group_access])
        end
      end
    end
  end
end
