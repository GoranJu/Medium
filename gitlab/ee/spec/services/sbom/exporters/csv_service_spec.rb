# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Exporters::CsvService, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:export) { build_stubbed(:dependency_list_export) }
  let_it_be(:sbom_occurrences) { Sbom::Occurrence.all }

  let(:service_class) { described_class.new(export, sbom_occurrences) }

  describe '#header' do
    subject { service_class.header }

    it { is_expected.to eq("Name,Version,Packager,Location\n") }
  end

  context 'when block is not given' do
    it 'renders csv to string' do
      expect(service_class.generate).to be_a String
    end
  end

  context 'when block is given' do
    it 'returns handle to Tempfile' do
      expect(service_class.generate { |file| file }).to be_a Tempfile
    end
  end

  describe '#generate' do
    subject(:csv) { CSV.parse(service_class.generate, headers: true) }

    let(:header) { %w[Name Version Packager Location] }

    context 'when the organization does not have dependencies' do
      it { is_expected.to match_array([header]) }
    end

    context 'when the organization has dependencies' do
      let_it_be(:bundler) { create(:sbom_component, :bundler) }
      let_it_be(:bundler_v1) { create(:sbom_component_version, component: bundler, version: "1.0.0") }

      let_it_be(:occurrence) do
        create(:sbom_occurrence, :mit, project: project, component: bundler, component_version: bundler_v1)
      end

      it 'returns correct content' do
        expect(csv[0]['Name']).to eq(occurrence.name)
        expect(csv[0]['Version']).to eq(occurrence.version)
        expect(csv[0]['Packager']).to eq(occurrence.package_manager)
        expect(csv[0]['Location']).to eq(occurrence.location[:blob_path])
      end

      it 'avoids N+1 queries' do
        control = ActiveRecord::QueryRecorder.new do
          service_class.generate
        end

        create_list(:sbom_occurrence, 3, project: project, source: create(:sbom_source))

        expect do
          service_class.generate
        end.to issue_same_number_of_queries_as(control).or_fewer
      end
    end
  end
end
