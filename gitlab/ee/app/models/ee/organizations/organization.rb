# frozen_string_literal: true

module EE
  module Organizations
    module Organization
      extend ActiveSupport::Concern

      prepended do
        has_many :active_projects,
          -> { non_archived },
          class_name: 'Project',
          inverse_of: :organization
        has_many :vulnerability_exports, class_name: 'Vulnerabilities::Export'
        has_many :sbom_sources, class_name: 'Sbom::Source'
        has_many :sbom_source_packages, class_name: 'Sbom::SourcePackage'
        has_many :sbom_components, class_name: 'Sbom::Component'
        has_many :sbom_component_versions, class_name: 'Sbom::ComponentVersion'
      end
    end
  end
end
