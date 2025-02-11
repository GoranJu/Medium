# frozen_string_literal: true

module Sbom
  module Exporters
    class CsvService
      attr_reader :sbom_occurrences

      def initialize(_export, sbom_occurrences)
        @sbom_occurrences = sbom_occurrences
      end

      def generate(&block)
        csv_builder.render(&block)
      end

      def header
        CSV.generate_line(mapping.keys)
      end

      private

      def preloads
        [
          :source,
          :component_version,
          { project: [namespace: :route] }
        ]
      end

      def csv_builder
        @csv_builder ||= CsvBuilder.new(sbom_occurrences, mapping, preloads,
          replace_newlines: true)
      end

      def mapping
        {
          s_('DependencyListExport|Name') => 'component_name',
          s_('DependencyListExport|Version') => 'version',
          s_('DependencyListExport|Packager') => 'package_manager',
          s_('DependencyListExport|Location') => ->(occurrence) { occurrence.location[:blob_path] }
        }
      end
    end
  end
end
