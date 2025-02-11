# frozen_string_literal: true

class AdjournedProjectDeletionWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  data_consistency :always

  sidekiq_options retry: 3
  include ExceptionBacktrace

  feature_category :groups_and_projects

  def perform(project_id)
    project = Project.find(project_id)
    user = project.deleting_user

    Projects::AdjournedDeletionService
      .new(project: project, current_user: user)
      .execute
  rescue ActiveRecord::RecordNotFound => error
    logger.error("Failed to delete project (#{project_id}): #{error.message}")
  end
end
