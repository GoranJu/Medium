# frozen_string_literal: true

module EE
  module Groups
    module GroupLinks
      module UpdateService
        extend ::Gitlab::Utils::Override
        include GroupLinksHelper

        override :execute
        def execute(group_link_params)
          super.tap do |group_link|
            log_audit_event(group_link)
          end
        end

        private

        override :remove_unallowed_params
        def remove_unallowed_params
          if group_link_params[:member_role_id] && !custom_role_for_group_link_enabled?(group_link.shared_group)
            group_link_params.delete(:member_role_id)
          end

          super
        end

        def log_audit_event(group_link)
          changes = group_link.previous_changes.symbolize_keys.except(:updated_at)
          return unless changes.present?

          audit_context = {
            name: "group_share_with_group_link_updated",
            author: current_user,
            scope: group_link.shared_group,
            target: group_link.shared_with_group,
            stream_only: false,
            message: "Updated #{group_link.shared_with_group.name}'s " \
                     "access params for the group #{group_link.shared_group.name}",
            additional_details: {
              changes: [
                access_change(changes[:group_access]),
                expiry_change(changes[:expires_at]),
                member_role_change(changes[:member_role_id])
              ].compact
            }.compact
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def access_change(change = nil)
          return if change.blank?

          {
            change: :group_access,
            from: ::Gitlab::Access.human_access(change.first),
            to: ::Gitlab::Access.human_access(change.last)
          }
        end

        def expiry_change(change = nil)
          return if change.blank?

          {
            change: :expires_at,
            from: change.first.to_s,
            to: change.last.to_s
          }
        end

        def member_role_change(change = nil)
          return if change.blank?

          {
            change: :member_role,
            from: change.first.to_s,
            to: change.last.to_s
          }
        end
      end
    end
  end
end
