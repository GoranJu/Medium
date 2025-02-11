# frozen_string_literal: true

module Sbom
  class Occurrence < Gitlab::Database::SecApplicationRecord
    LICENSE_COLUMNS = [:spdx_identifier, :name, :url].freeze
    include EachBatch

    belongs_to :component, optional: false, inverse_of: :occurrences
    belongs_to :component_version, inverse_of: :occurrences
    belongs_to :project, optional: false
    belongs_to :pipeline, class_name: 'Ci::Pipeline'
    belongs_to :source, inverse_of: :occurrences
    belongs_to :source_package, optional: true, inverse_of: :occurrences

    has_many :occurrences_vulnerabilities,
      class_name: 'Sbom::OccurrencesVulnerability',
      foreign_key: :sbom_occurrence_id,
      inverse_of: :occurrence

    has_many :vulnerabilities, through: :occurrences_vulnerabilities

    enum highest_severity: ::Enums::Vulnerability.severity_levels
    enum reachability: ::Enums::Sbom.reachability_types, _suffix: true

    validates :commit_sha, presence: true
    validates :uuid, presence: true, uniqueness: { case_sensitive: false }
    validates :package_manager, length: { maximum: 255 }
    validates :component_name, length: { maximum: 255 }
    validates :input_file_path, length: { maximum: 1024 }
    validates :licenses, json_schema: { filename: 'sbom_occurrences-licenses' }

    delegate :name, to: :component
    delegate :purl_type, to: :component
    delegate :component_type, to: :component
    delegate :version, to: :component_version, allow_nil: true
    delegate :source_package_name, to: :component_version, allow_nil: true

    alias_attribute :packager, :package_manager

    scope :order_by_id, -> { order(id: :asc) }

    scope :order_by_component_name, ->(direction) do
      order(component_name: direction)
    end

    scope :order_by_package_name, ->(direction) do
      order(package_manager: direction, component_name: :asc)
    end

    scope :order_by_spdx_identifier, ->(direction, depth: 1) do
      order(Gitlab::Pagination::Keyset::Order.build(
        0.upto(depth).map do |index|
          sql = Arel.sql("(licenses#>'{#{index},spdx_identifier}')::text")
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: "spdx_identifier_#{index}",
            order_expression: direction == "desc" ? sql.desc : sql.asc,
            sql_type: 'text',
            nullable: :nulls_last
          )
        end
      ))
    end

    scope :by_licenses, ->(licenses, depth: 1) do
      unknown, ids = licenses.partition { |id| id.casecmp?("unknown") }

      id_filters = (0..depth).map do |index|
        "(licenses#>'{#{index},spdx_identifier}' ?| array[:licenses])"
      end

      query_parts = []
      query_parts.append(*id_filters) if ids.present?
      query_parts.append("licenses = '[]'") if unknown.present?

      return none unless query_parts.present?

      where(query_parts.join(' OR '), licenses: Array(ids))
    end

    scope :by_primary_license, ->(license_ids) do
      return none if license_ids.blank?

      license_ids.map do |id|
        if id.casecmp('unknown') == 0
          where("licenses = '[]'")
        else
          where("(licenses -> 0 ->> 'spdx_identifier')::text = ?", id)
        end
      end.reduce(:or)
    end

    scope :unarchived, -> { where(archived: false) }
    scope :by_project_ids, ->(project_ids) do
      where(project_id: project_ids)
    end
    scope :by_uuids, ->(uuids) { where(uuid: uuids) }
    scope :for_namespace_and_descendants, ->(namespace) do
      where("traversal_ids >= ('{?}')", namespace.traversal_ids)
        .where("traversal_ids < ('{?}')", namespace.next_traversal_ids)
    end

    scope :filter_by_package_managers, ->(package_managers) do
      where(package_manager: package_managers)
    end

    scope :filter_by_components, ->(components) { where(component: components) }
    scope :filter_by_source_packages, ->(source_packages) { where(source_package: source_packages) }
    scope :filter_by_component_names, ->(component_names) do
      where(component_name: component_names)
    end

    scope :filter_by_source_types, ->(source_types) do
      left_outer_joins(:source).where(sbom_sources: { source_type: source_types })
    end

    scope :filter_by_source_id, ->(source_id) do
      where(source_id: source_id)
    end

    scope :filter_by_component_names, ->(component_names) do
      where(component_name: component_names)
    end

    scope :filter_by_component_ids, ->(component_ids) do
      where(component_id: component_ids)
    end

    scope :filter_by_search_with_component_and_group, ->(search, component_id, group) do
      relation = for_namespace_and_descendants(group)
        .where(component_version_id: component_id)

      if search.present?
        relation.where('input_file_path ILIKE ?', "%#{sanitize_sql_like(search.to_s)}%") # rubocop:disable GitlabSecurity/SqlInjection -- This cop is a false positive as we are using parameterization via ?
      else
        relation
      end
    end

    scope :with_component, -> { includes(:component) }
    scope :with_licenses, -> do
      columns = LICENSE_COLUMNS.map { |column| "#{column} TEXT" }.join(", ")
      sbom_licenses = Arel.sql(<<~SQL.squish)
      LEFT JOIN LATERAL jsonb_to_recordset(sbom_occurrences.licenses) AS sbom_licenses(#{columns}) ON TRUE
      SQL
      joins(sbom_licenses)
        .where("licenses != '[]'")
        .where.not(sbom_licenses: { spdx_identifier: nil })
    end
    scope :with_project_route, -> { preload(project: :route) }
    scope :with_project_namespace, -> { includes(project: [namespace: :route]) }
    scope :with_source, -> { includes(:source) }
    scope :with_version, -> { includes(:component_version) }
    scope :with_pipeline_project_and_namespace, -> { preload(pipeline: { project: :namespace }) }
    scope :with_vulnerabilities, -> { preload(:vulnerabilities) }
    scope :with_component_source_version_and_project, -> do
      preload(:project).includes(:component, :source, :component_version)
    end
    scope :with_project_setting, -> { preload(project: :project_setting) }
    scope :filter_by_non_nil_component_version, -> { where.not(component_version: nil) }

    scope :order_by_severity, ->(direction) do
      order(highest_severity_arel_nodes(direction))
    end

    scope :in_parent_group_after_and_including, ->(sbom_occurrence) do
      where(arel_grouping_by_traversal_ids_and_id.gteq(sbom_occurrence.arel_grouping_by_traversal_ids_and_id))
    end
    scope :in_parent_group_before_and_including, ->(sbom_occurrence) do
      where(arel_grouping_by_traversal_ids_and_id.lteq(sbom_occurrence.arel_grouping_by_traversal_ids_and_id))
    end
    scope :order_traversal_ids_asc, -> do
      reorder(Gitlab::Pagination::Keyset::Order.build([
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'traversal_ids',
          order_expression: arel_table[:traversal_ids].asc,
          nullable: :not_nullable
        ),
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'id',
          order_expression: arel_table[:id].asc
        )
      ]))
    end

    def self.arel_grouping_by_traversal_ids_and_id
      arel_table.grouping([arel_table['traversal_ids'], arel_table['id']])
    end

    def arel_grouping_by_traversal_ids_and_id
      self.class.arel_table.grouping([database_serialized_traversal_ids, id])
    end

    def location
      {
        blob_path: input_file_blob_path,
        path: input_file_path,
        top_level: false,
        ancestors: ancestors
      }
    end

    private

    def input_file_blob_path
      return unless input_file_path.present?

      Gitlab::Routing.url_helpers.project_blob_path(project, File.join(commit_sha, input_file_path))
    end

    def self.highest_severity_arel_nodes(direction)
      return Sbom::Occurrence.arel_table[:highest_severity].asc.nulls_first if direction == 'asc'

      Sbom::Occurrence.arel_table[:highest_severity].desc.nulls_last
    end

    def database_serialized_traversal_ids
      self.class.attribute_types['traversal_ids']
                .serialize(traversal_ids)
                .then { |serialized_array| self.class.connection.quote(serialized_array) }
                .then { |quoted_array| Arel::Nodes::SqlLiteral.new(quoted_array) }
    end
  end
end
