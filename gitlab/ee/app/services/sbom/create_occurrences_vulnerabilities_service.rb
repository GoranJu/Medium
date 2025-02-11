# frozen_string_literal: true

module Sbom
  class CreateOccurrencesVulnerabilitiesService
    def self.execute(finding_data)
      new(finding_data).execute
    end

    def initialize(finding_data)
      @finding_data = finding_data
    end

    def execute
      return unless filtered_data.present?

      result = fetch_occurrence_data
      return if result.cmd_tuples == 0

      attributes = result.map do |data|
        {
          sbom_occurrence_id: data['id'],
          vulnerability_id: vulnerability_ids[data['uuid']],
          project_id: data['project_id']
        }
      end

      Sbom::OccurrencesVulnerability.upsert_all(attributes, unique_by: [:sbom_occurrence_id, :vulnerability_id])
    end

    private

    attr_reader :finding_data

    # rubocop:disable CodeReuse/ActiveRecord -- Custom query
    def fetch_occurrence_data
      cte_sql = "WITH cte (uuid, package_manager, component_name, version, project_id) AS (#{cte_values})"
      select_sql = Sbom::Occurrence
        .joins('INNER JOIN cte
          ON cte.package_manager = sbom_occurrences.package_manager
          AND cte.component_name = sbom_occurrences.component_name
          AND cte.project_id = sbom_occurrences.project_id')
        .joins('INNER JOIN sbom_component_versions
          ON sbom_component_versions.id = sbom_occurrences.component_version_id
          AND cte.version = sbom_component_versions.version')
        .select('cte.uuid', 'cte.project_id', 'sbom_occurrences.id').to_sql

      full_query = [cte_sql, select_sql].join("\n")

      Sbom::Occurrence.connection.execute(full_query)
    end
    # rubocop:enable CodeReuse/ActiveRecord

    def cte_values
      Arel::Nodes::ValuesList.new(filtered_data).to_sql
    end

    def filtered_data
      @filtered_data ||= finding_data.filter_map do |data|
        next if Feature.disabled?(:update_sbom_occurrences_vulnerabilities_on_cvs,
          Project.actor_from_id(data[:project_id]))

        [data[:uuid], data[:purl_type], data[:package_name], data[:package_version], data[:project_id]]
      end
    end

    def vulnerability_ids
      @vulnerability_ids ||= finding_data.to_h { |data| [data[:uuid], data[:vulnerability_id]] }
    end
  end
end
