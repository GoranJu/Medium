# frozen_string_literal: true

module EE
  # Namespaces::ProjectsFinder
  #
  # Extends Namespaces::ProjectsFinder
  #
  # Added arguments:
  #   params:
  #     has_vulnerabilities: boolean
  #     has_code_coverage: boolean
  #     sbom_component_id: integer
  #
  module Namespaces
    module ProjectsFinder
      extend ::Gitlab::Utils::Override

      private

      override :filter_projects
      def filter_projects(collection)
        collection = super(collection)
        collection = with_vulnerabilities(collection)
        collection = with_code_coverage(collection)
        collection = with_compliance_framework(collection)
        collection = by_negated_compliance_framework_filters(collection)
        collection = with_sbom_component_version(collection)
        by_compliance_framework_presence(collection)
      end

      def with_compliance_framework(collection)
        filter_id = params.dig(:compliance_framework_filters, :id)
        filter_ids = params.dig(:compliance_framework_filters, :ids) || []

        filter_ids << filter_id unless filter_id.nil?

        return collection if filter_ids.blank?

        filter_ids.each do |framework_id|
          collection = collection.with_compliance_frameworks(framework_id)
        end

        collection
      end

      def by_negated_compliance_framework_filters(collection)
        filter_id = params.dig(:compliance_framework_filters, :not, :id)
        filter_ids = params.dig(:compliance_framework_filters, :not, :ids) || []

        filter_ids << filter_id unless filter_id.nil?

        return collection if filter_ids.blank?

        collection.not_with_compliance_frameworks(filter_ids)
      end

      def by_compliance_framework_presence(collection)
        filter = params.dig(:compliance_framework_filters, :presence_filter)
        return collection if filter.nil?

        case filter.to_sym
        when :any
          collection.any_compliance_framework
        when :none
          collection.missing_compliance_framework
        else
          raise ArgumentError, "The presence filter is not supported: '#{filter}'"
        end
      end

      override :sort
      def sort(items)
        if params[:sort] == :excess_repo_storage_size_desc
          return items.order_by_excess_repo_storage_size_desc(namespace.actual_size_limit)
        end

        super(items)
      end

      def with_vulnerabilities(items)
        return items unless params[:has_vulnerabilities].present?

        items.has_vulnerabilities
      end

      def with_code_coverage(items)
        return items unless params[:has_code_coverage].present?

        items.with_coverage_feature_usage(default_branch: true)
      end

      def with_sbom_component_version(items)
        return items unless params[:sbom_component_id].present?

        project_ids_with_component = ::Gitlab::Database::NamespaceProjectIdsEachBatch.new(
          group_id: namespace.id,
          resolver: method(:project_ids_with_sbom_component)
        ).execute

        items.id_in(project_ids_with_component)
      end

      # Given a batch of projects, filter to only return project IDs that have sbom occurrences with
      def project_ids_with_sbom_component(batch)
        # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- Limit of 100 max per batch definition
        id_list = Arel::Nodes::ValuesList.new(batch.pluck_primary_key.map { |v| [v] }).to_sql
        filter_query = Sbom::Occurrence.where(
          'component_version_id = ? AND project_ids.id = project_id', params[:sbom_component_id]
        ).limit(1).select(1)

        Sbom::Occurrence.from(
          "(#{id_list}) AS project_ids(id), LATERAL (#{filter_query.to_sql}) AS #{Sbom::Occurrence.table_name}"
        ).pluck("project_ids.id")
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord
      end
    end
  end
end
