# frozen_string_literal: true

module Sbom
  module Exporters
    class JsonArrayService
      include WriteBlob

      def initialize(_export, sbom_occurrences)
        @sbom_occurrences = sbom_occurrences
      end

      attr_reader :sbom_occurrences

      def generate(&block)
        write_json_blob(data, &block)
      end

      private

      def data
        [].tap do |list|
          iterator.each_batch do |batch|
            list.concat(build_list_for(batch))
          end
        end
      end

      def build_list_for(batch)
        batch.with_source.with_version.map do |occurrence|
          {
            name: occurrence.component_name,
            packager: occurrence.package_manager,
            version: occurrence.version,
            licenses: occurrence.licenses,
            location: occurrence.location
          }
        end
      end

      def iterator
        Gitlab::Pagination::Keyset::Iterator.new(scope: sbom_occurrences)
      end
    end
  end
end
