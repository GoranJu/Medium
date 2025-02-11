# frozen_string_literal: true

module Vulnerabilities
  class BulkSeverityOverrideService < BaseBulkUpdateService
    def initialize(current_user, vulnerability_ids, comment, severity)
      super(current_user, vulnerability_ids, comment)
      @new_severity = severity
    end

    private

    def update(vulnerabilities_ids)
      vulnerabilities = vulnerabilities_to_update(vulnerabilities_ids)
      vulnerability_attrs = vulnerabilities_attributes(vulnerabilities)
      return if vulnerability_attrs.empty?

      db_attributes = db_attributes_for(vulnerability_attrs)

      Gitlab::Database::SecApplicationRecord.transaction do
        update_support_tables(vulnerabilities, db_attributes)
        vulnerabilities.update_all(db_attributes[:vulnerabilities])
      end
    end

    def authorized_for_project(project)
      super && Feature.enabled?(:vulnerability_severity_override, project.root_ancestor)
    end

    def severity_overrides_attributes_for(vulnerability_attrs)
      vulnerability_attrs.map do |id, severity, project_id|
        {
          vulnerability_id: id,
          original_severity: severity,
          new_severity: @new_severity,
          project_id: project_id,
          author_id: user.id,
          created_at: now,
          updated_at: now
        }
      end
    end

    def db_attributes_for(vulnerability_attrs)
      {
        vulnerabilities: vulnerabilities_update_attributes,
        severity_overrides: severity_overrides_attributes_for(vulnerability_attrs)
      }
    end

    def vulnerabilities_to_update(ids)
      # rubocop: disable CodeReuse/ActiveRecord -- context specific
      Vulnerability.id_in(ids).where.not(severity: @new_severity)
      # rubocop: enable CodeReuse/ActiveRecord
    end

    def update_support_tables(vulnerabilities, db_attributes)
      Vulnerabilities::Finding.by_vulnerability(vulnerabilities).update_all(severity: @new_severity)
      Vulnerabilities::SeverityOverride.insert_all!(db_attributes[:severity_overrides])
    end

    def vulnerabilities_attributes(vulnerabilities)
      vulnerabilities
        .select(:id, :severity, :project_id).with_projects
        .map { |v| [v.id, v.severity, v.project_id, v.project.project_namespace_id] }
    end

    def vulnerabilities_update_attributes
      {
        severity: @new_severity,
        updated_at: now
      }
    end
  end
end
