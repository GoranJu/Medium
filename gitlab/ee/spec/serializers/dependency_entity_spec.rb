# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyEntity, feature_category: :dependency_management do
  describe '#as_json' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:user) { create(:user, organizations: [organization]) }
    let_it_be(:project) { create(:project, :repository, :private, :in_group, organization: organization) }
    let_it_be(:group) { project.group }
    let_it_be(:sbom_occurrence) { create(:sbom_occurrence, :mit, :bundler, :with_ancestors, project: project) }
    let(:request_params) { { project: project, group: group, user: user } }
    let(:request) { EntityRequest.new(**request_params) }
    let(:params) { { request: request } }

    subject { described_class.represent(sbom_occurrence, request: request).as_json }

    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(security_dashboard: true, license_scanning: true)
    end

    it 'renders the proper representation' do
      expect(subject.as_json).to eq({
        "name" => sbom_occurrence.name,
        "occurrence_count" => 1,
        "packager" => sbom_occurrence.packager,
        "project_count" => 1,
        "version" => sbom_occurrence.version,
        "licenses" => sbom_occurrence.licenses,
        "component_id" => sbom_occurrence.component_version_id,
        "vulnerability_count" => 0,
        "occurrence_id" => sbom_occurrence.id
      })
    end

    context "when there are no known licenses" do
      let_it_be(:sbom_occurrence) { create(:sbom_occurrence, project: project) }

      it 'injects an unknown license' do
        expect(subject.as_json['licenses']).to match_array([
          "spdx_identifier" => "unknown",
          "name" => "unknown",
          "url" => nil
        ])
      end
    end

    context 'with an organization' do
      let_it_be(:project) { create(:project, organization: organization) }
      let_it_be(:sbom_occurrence) { create(:sbom_occurrence, :mit, :bundler, project: project) }
      let(:request_params) { { project: nil, group: nil, user: user, organization: organization } }

      it 'renders the proper representation' do
        expect(subject.keys).to match_array([
          :name, :packager, :version, :licenses, :location, :occurrence_id, :vulnerability_count
        ])

        expect(subject[:name]).to eq(sbom_occurrence.name)
        expect(subject[:packager]).to eq(sbom_occurrence.packager)
        expect(subject[:version]).to eq(sbom_occurrence.version)
      end

      it 'renders location' do
        expect(subject.dig(:location, :blob_path)).to eq(sbom_occurrence.location[:blob_path])
        expect(subject.dig(:location, :path)).to eq(sbom_occurrence.location[:path])
      end

      it 'renders each license' do
        sbom_occurrence.licenses.each_with_index do |_license, index|
          expect(subject.dig(:licenses, index, :name)).to eq(sbom_occurrence.licenses[index]['name'])
          expect(subject.dig(:licenses, index, :spdx_identifier)).to eq(
            sbom_occurrence.licenses[index]['spdx_identifier']
          )
          expect(subject.dig(:licenses, index, :url)).to eq(sbom_occurrence.licenses[index]['url'])
        end
      end
    end

    context 'when all required features are unavailable' do
      before do
        stub_licensed_features(security_dashboard: false, license_scanning: false)
      end

      it 'does not include licenses and vulnerabilities' do
        is_expected.not_to match(hash_including(:vulnerabilities, :licenses))
      end
    end
  end
end
