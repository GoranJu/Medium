# frozen_string_literal: true

module Projects
  class MarkForDeletionService < BaseService
    include EE::SecurityOrchestrationHelper # rubocop: disable Cop/InjectEnterpriseEditionModule -- EE-only concern

    def execute
      return success if project.marked_for_deletion_at?
      return error('Cannot mark project for deletion: feature not supported') unless License.feature_available?(:adjourned_deletion_for_projects_and_groups)

      if reject_security_policy_project_deletion?
        return error(s_('SecurityOrchestration|Project cannot be deleted because it is linked as a security policy project'))
      end

      result = ::Projects::UpdateService.new(
        project,
        current_user,
        project_update_service_params
      ).execute
      log_error(result[:message]) if result[:status] == :error

      if result[:status] == :success
        log_event

        ## Trigger root statistics refresh, to skip project_statistics of
        ## projects marked for deletion
        Namespaces::ScheduleAggregationWorker.perform_async(project.namespace_id)
      end

      result
    end

    private

    def log_event
      log_audit_event
      log_info("User #{current_user.id} marked project #{project.full_path} for deletion")
    end

    def log_audit_event
      audit_context = {
        name: 'project_deletion_marked',
        author: current_user,
        scope: project,
        target: project,
        message: 'Project marked for deletion'
      }

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end

    def project_update_service_params
      params = {
        archived: true,
        name: "#{project.name}-deleted-#{project.id}",
        path: "#{project.path}-deleted-#{project.id}",
        marked_for_deletion_at: Time.current.utc,
        deleting_user: current_user
      }
      params[:hidden] = true unless project.feature_available?(:adjourned_deletion_for_projects_and_groups)
      params
    end

    def reject_security_policy_project_deletion?
      security_configurations_preventing_project_deletion(project).exists?
    end
  end
end
