# frozen_string_literal: true

module Security
  class ProjectStatistics < Gitlab::Database::SecApplicationRecord
    self.primary_key = :project_id
    self.table_name = 'project_security_statistics'

    belongs_to :project, optional: false

    scope :by_projects, ->(project_ids) { where(project_id: project_ids) }

    class << self
      def create_for(project)
        upsert({ project_id: project.id })

        find_by_project_id(project.id)
      end

      def sum_vulnerability_count_for_group(group)
        if Feature.enabled?(:sum_vulnerability_count_for_group_using_vulnerability_statistics, group)
          project_ids = ::Vulnerabilities::Statistic.by_group(group).unarchived.select(:project_id)
          return Security::ProjectStatistics.where(project_id: project_ids).sum(:vulnerability_count)
        end

        Security::ProjectStatistics
          .where(project_id: group.all_project_ids)
          .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/515040')
          .sum(:vulnerability_count)
      end
    end

    def increase_vulnerability_counter!(increment)
      self.class.by_projects(project_id).update_all("vulnerability_count = vulnerability_count + #{increment}")
    end

    def decrease_vulnerability_counter!(decrement)
      self.class.by_projects(project_id).update_all("vulnerability_count = vulnerability_count - #{decrement}")
    end
  end
end
