# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Exporters::JsonArrayService, feature_category: :dependency_management do
  describe '#generate' do
    let_it_be(:group) { create(:group) }
    let(:sbom_occurrences) { Sbom::Occurrence.for_namespace_and_descendants(group).order_by_id }
    let(:service_class) { described_class.new(nil, sbom_occurrences) }

    subject(:dependencies) { Gitlab::Json.parse(service_class.generate) }

    before do
      stub_licensed_features(dependency_scanning: true)
    end

    context 'when the group does not have dependencies' do
      it { is_expected.to be_empty }
    end

    context 'when the group has dependencies' do
      let_it_be(:project) { create(:project, :public, group: group) }

      let_it_be(:bundler) { create(:sbom_component, :bundler) }
      let_it_be(:bundler_v1) { create(:sbom_component_version, component: bundler, version: "1.0.0") }

      let_it_be(:occurrence_1) { create(:sbom_occurrence, :mit, project: project) }
      let_it_be(:occurrence_2) { create(:sbom_occurrence, :apache_2, project: project) }
      let_it_be(:occurrence_3) { create(:sbom_occurrence, :apache_2, :mpl_2, project: project) }

      let_it_be(:occurrence_of_bundler_v1) do
        create(:sbom_occurrence, :mit, project: project, component: bundler, component_version: bundler_v1)
      end

      let_it_be(:other_occurrence_of_bundler_v1) do
        create(:sbom_occurrence, :mit, project: project, component: bundler, component_version: bundler_v1)
      end

      it 'includes each occurrence excluding archived projects' do
        expect(dependencies).to eq([
          {
            "name" => occurrence_1.component_name,
            "version" => occurrence_1.version,
            "packager" => occurrence_1.package_manager,
            "licenses" => occurrence_1.licenses,
            "location" => occurrence_1.location.as_json
          },
          {
            "name" => occurrence_2.component_name,
            "version" => occurrence_2.version,
            "packager" => occurrence_2.package_manager,
            "licenses" => occurrence_2.licenses,
            "location" => occurrence_2.location.as_json
          },
          {
            "name" => occurrence_3.component_name,
            "version" => occurrence_3.version,
            "packager" => occurrence_3.package_manager,
            "licenses" => occurrence_3.licenses,
            "location" => occurrence_3.location.as_json
          },
          {
            "name" => occurrence_of_bundler_v1.component_name,
            "version" => occurrence_of_bundler_v1.version,
            "packager" => occurrence_of_bundler_v1.package_manager,
            "licenses" => occurrence_of_bundler_v1.licenses,
            "location" => occurrence_of_bundler_v1.location.as_json
          },
          {
            "name" => other_occurrence_of_bundler_v1.component_name,
            "version" => other_occurrence_of_bundler_v1.version,
            "packager" => other_occurrence_of_bundler_v1.package_manager,
            "licenses" => other_occurrence_of_bundler_v1.licenses,
            "location" => other_occurrence_of_bundler_v1.location.as_json
          }
        ])
      end
    end
  end
end
