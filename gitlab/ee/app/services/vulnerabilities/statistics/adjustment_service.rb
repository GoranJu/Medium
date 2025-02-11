# frozen_string_literal: true

module Vulnerabilities
  module Statistics
    class AdjustmentService
      TooManyProjectsError = Class.new(StandardError)

      UPSERT_SQL = <<~SQL
        INSERT INTO vulnerability_statistics
          (project_id, archived, traversal_ids, total, info, unknown, low, medium, high, critical, letter_grade, created_at, updated_at)
          (%{stats_sql})
        ON CONFLICT (project_id)
        DO UPDATE SET
          total = EXCLUDED.total,
          info = EXCLUDED.info,
          unknown = EXCLUDED.unknown,
          low = EXCLUDED.low,
          medium = EXCLUDED.medium,
          high = EXCLUDED.high,
          critical = EXCLUDED.critical,
          letter_grade = EXCLUDED.letter_grade,
          updated_at = EXCLUDED.updated_at
      SQL

      STATS_SQL = <<~SQL
        SELECT
          project_ids.project_id AS project_id,
          project_attributes.archived AS archived,
          project_attributes.traversal_ids AS traversal_ids,
          COALESCE(severity_counts.total, 0) AS total,
          COALESCE(severity_counts.info, 0) AS info,
          COALESCE(severity_counts.unknown, 0) AS unknown,
          COALESCE(severity_counts.low, 0) AS low,
          COALESCE(severity_counts.medium, 0) AS medium,
          COALESCE(severity_counts.high, 0) AS high,
          COALESCE(severity_counts.critical, 0) AS critical,
          (
            CASE
            WHEN severity_counts.critical > 0 THEN
              #{Statistic.letter_grades['f']}
            WHEN severity_counts.high > 0 OR severity_counts.unknown > 0 THEN
              #{Statistic.letter_grades['d']}
            WHEN severity_counts.medium > 0 THEN
              #{Statistic.letter_grades['c']}
            WHEN severity_counts.low > 0 THEN
              #{Statistic.letter_grades['b']}
            ELSE
              #{Statistic.letter_grades['a']}
            END
          ) AS letter_grade,
          now() AS created_at,
          now() AS updated_at
        FROM unnest(ARRAY[%{project_ids}]) project_ids(project_id)
        JOIN (%{project_attributes}) project_attributes(project_id, archived, traversal_ids)
          ON project_attributes.project_id = project_ids.project_id
        LEFT OUTER JOIN(
          SELECT
            vulnerability_reads.project_id AS project_id,
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['info']}) as info,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['unknown']}) as unknown,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['low']}) as low,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['medium']}) as medium,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['high']}) as high,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['critical']}) as critical
          FROM vulnerability_reads
          WHERE
            vulnerability_reads.project_id IN (%{project_ids}) AND
            vulnerability_reads.state IN (%{active_states})
          GROUP BY vulnerability_reads.project_id
        ) AS severity_counts ON severity_counts.project_id = project_ids.project_id
      SQL

      MAX_PROJECTS = 1_000

      def self.execute(project_ids)
        new(project_ids).execute
      end

      def initialize(project_ids)
        raise TooManyProjectsError, "Cannot adjust statistics for more than #{MAX_PROJECTS} projects" if project_ids.size > MAX_PROJECTS

        self.project_ids = project_ids
      end

      def execute
        filter_project_ids
        return if project_ids.blank?

        connection.execute(upsert_sql)
      end

      private

      attr_accessor :project_ids

      delegate :connection, to: Statistic, private: true

      def filter_project_ids
        self.project_ids = Project.id_in(project_ids).pluck_primary_key
      end

      def upsert_sql
        UPSERT_SQL % { stats_sql: stats_sql }
      end

      def stats_sql
        STATS_SQL % {
          project_ids: project_ids.join(', '),
          project_attributes: project_attributes_as_values_sql,
          active_states: active_states
        }
      end

      def project_attributes_as_values_sql
        # rubocop:disable CodeReuse/ActiveRecord -- not reusable
        attributes = Project.where(id: project_ids).joins_namespace.limit(project_ids.length)
                              .pluck(:id, :archived, :traversal_ids)
        # rubocop:enable CodeReuse/ActiveRecord

        tuples = attributes.map do |row|
          [
            row[0],
            row[1],
            Arel.sql("ARRAY#{row[2]}::bigint[]")
          ]
        end

        Arel::Nodes::ValuesList.new(tuples).to_sql
      end

      def active_states
        Vulnerability.active_state_values.join(', ')
      end
    end
  end
end
