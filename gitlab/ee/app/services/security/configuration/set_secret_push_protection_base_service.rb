# frozen_string_literal: true

module Security
  module Configuration
    class SetSecretPushProtectionBaseService
      PROJECTS_BATCH_SIZE = 100
      def initialize(subject:, enable:, current_user:, excluded_projects_ids: [])
        @subject = subject
        @enable = enable
        @current_user = current_user
        @excluded_projects_ids = excluded_projects_ids || []
        @filtered_out_projects_ids = []
      end

      def execute
        return unless valid_request?

        any_updated = false
        project_ids = subject_project_ids
        ApplicationRecord.transaction do
          project_ids.each_slice(PROJECTS_BATCH_SIZE) do |project_ids_batch|
            updated_count = update_security_setting(project_ids_batch)
            any_updated ||= updated_count > 0
          end
          audit if any_updated
        end
        @enable
      end

      protected

      def valid_request?
        @subject.present? && @current_user.present? && [true, false].include?(@enable)
      end

      def update_security_setting(project_ids)
        # rubocop:disable CodeReuse/ActiveRecord -- Specific use-case for this service
        updated_records = ProjectSecuritySetting.for_projects(project_ids)
                              .where(secret_push_protection_enabled: !@enable)
                                .update_all(secret_push_protection_enabled: @enable,
                                  updated_at: Time.current)
        # rubocop:enable CodeReuse/ActiveRecord

        create_missing_security_setting(project_ids) + updated_records
      end

      def create_missing_security_setting(project_ids)
        projects_without_security_setting = Project.id_in(project_ids).without_security_setting
        security_setting_attributes = projects_without_security_setting.map do |project|
          {
            project_id: project.id,
            secret_push_protection_enabled: @enable,
            updated_at: Time.current
          }
        end
        return 0 unless security_setting_attributes.any?

        ProjectSecuritySetting.upsert_all(security_setting_attributes).length
      end

      def build_audit_context(name:, message:)
        {
          name: name,
          author: @current_user,
          scope: @subject,
          target: @subject,
          message: message
        }
      end

      def audit
        raise NotImplementedError
      end

      def subject_project_ids
        raise NotImplementedError
      end
    end
  end
end
