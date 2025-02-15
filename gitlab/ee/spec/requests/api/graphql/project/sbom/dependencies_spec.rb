# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).dependencies', feature_category: :dependency_management do
  include ApiHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:variables) { { full_path: project.full_path } }
  let_it_be(:fields) do
    <<~FIELDS
      id
      name
      version
      packager
      location {
        blobPath
        path
      }
    FIELDS
  end

  let(:query) { pagination_query }

  let!(:occurrences) { create_list(:sbom_occurrence, 5, project: project) }

  def pagination_query(params = {})
    nodes = query_nodes(:dependencies, fields, include_pagination_info: true, args: params)
    graphql_query_for(:project, variables, nodes)
  end

  def package_manager_enum(value)
    Types::Sbom::PackageManagerEnum.values.find { |_, custom_value| custom_value.value == value }.first
  end

  before do
    stub_licensed_features(dependency_scanning: true)
  end

  subject { post_graphql(query, current_user: current_user, variables: variables) }

  it 'returns the expected dependency data when performing a well-formed query with an authorized user' do
    subject

    actual = graphql_data_at(:project, :dependencies, :nodes)
    expected = occurrences.map do |occurrence|
      {
        'id' => occurrence.to_gid.to_s,
        'name' => occurrence.name,
        'version' => occurrence.version,
        'packager' => package_manager_enum(occurrence.packager),
        'location' => {
          'blobPath' => "/#{project.full_path}/-/blob/#{occurrence.commit_sha}/#{occurrence.source.input_file_path}",
          'path' => occurrence.source.input_file_path
        }
      }
    end

    expect(actual).to match_array(expected)
  end

  it_behaves_like 'sorted paginated query' do
    def pagination_results_data(nodes)
      nodes.pluck('id')
    end

    let(:data_path) { %i[project dependencies] }
    let(:sort_argument) { {} }
    let(:first_param) { 2 }
    let(:all_records) { occurrences.sort_by(&:id).map { |occurrence| occurrence.to_gid.to_s } }
  end

  it 'does not make N+1 queries' do
    control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user, variables: variables) }

    create(:sbom_occurrence, project: project)

    expect { post_graphql(query, current_user: current_user, variables: variables) }.not_to exceed_query_limit(control)
  end

  context 'when dependencies have no source data' do
    let!(:occurrences) { create_list(:sbom_occurrence, 5, project: project, source: nil) }

    it 'returns nil for data which originates from a source' do
      subject

      actual = graphql_data_at(:project, :dependencies, :nodes)
      expected = occurrences.map do |occurrence|
        {
          'id' => occurrence.to_gid.to_s,
          'name' => occurrence.name,
          'version' => occurrence.version,
          'packager' => nil,
          'location' => {
            'blobPath' => nil,
            'path' => nil
          }
        }
      end

      expect(actual).to match_array(expected)
    end
  end

  context 'when dependencies have no version data' do
    let!(:occurrences) { create_list(:sbom_occurrence, 5, project: project, component_version: nil) }

    it 'returns a nil version' do
      subject

      actual = graphql_data_at(:project, :dependencies, :nodes)
      expected = occurrences.map do |occurrence|
        {
          'id' => occurrence.to_gid.to_s,
          'name' => occurrence.name,
          'version' => nil,
          'packager' => package_manager_enum(occurrence.packager),
          'location' => {
            'blobPath' => "/#{project.full_path}/-/blob/#{occurrence.commit_sha}/#{occurrence.source.input_file_path}",
            'path' => occurrence.source.input_file_path
          }
        }
      end

      expect(actual).to match_array(expected)
    end
  end

  context 'with an unauthorized user' do
    let_it_be(:current_user) { create(:user, guest_of: project) }

    it 'does not return dependency data' do
      subject
      expect(graphql_data_at(:project, :dependencies)).to be_blank
    end
  end

  context 'with sort as an argument' do
    let(:query) { pagination_query({ sort: sort_by }) }
    let(:sort_by) { :NAME_DESC }

    it 'sorts by component name descending' do
      subject

      result = graphql_data_at(:project, :dependencies, :nodes)
      names = result.pluck('name')

      expect(names).to eq(names.sort.reverse)
    end

    context 'with sorting by severity' do
      let(:occurrence_critical) { create(:sbom_occurrence, project: project, highest_severity: :critical) }
      let(:occurrence_low) { create(:sbom_occurrence, project: project, highest_severity: :low) }
      let(:occurrence_null) { create(:sbom_occurrence, project: project) }
      let!(:occurrences) { [occurrence_critical, occurrence_null, occurrence_low] }

      let(:sort_by) { :SEVERITY_DESC }

      it 'sorts by severity descending' do
        subject

        names = graphql_data_at(:project, :dependencies, :nodes).pluck('name')

        expect(names).to eq([occurrence_critical.name, occurrence_low.name, occurrence_null.name])
      end

      context 'with sort equal to SEVERITY_ASC' do
        let(:sort_by) { :SEVERITY_ASC }

        it 'sorts by severity ascending' do
          subject

          names = graphql_data_at(:project, :dependencies, :nodes).pluck('name')

          expect(names).to eq([occurrence_null.name, occurrence_low.name, occurrence_critical.name])
        end
      end
    end
  end

  context 'with package_managers as an argument' do
    let!(:occurrence) { create(:sbom_occurrence, project: project, packager_name: 'bundler') }
    let(:query) { pagination_query({ package_managers: [:BUNDLER] }) }

    it 'filters records based on the package manager name' do
      subject

      result = graphql_data_at(:project, :dependencies, :nodes)
      packagers = result.pluck('packager')

      expect(packagers).to eq([package_manager_enum(occurrence.packager)])
    end
  end

  context 'with component_names as an argument' do
    let!(:occurrence) { create(:sbom_occurrence, project: project) }
    let(:component_name) { occurrence.name }
    let(:query) { pagination_query({ component_names: [component_name] }) }

    it 'filters records based on the component name' do
      subject

      result = graphql_data_at(:project, :dependencies, :nodes)
      names = result.pluck('name')

      expect(names).to eq([component_name])
    end
  end

  context 'with source_types as an argument' do
    let!(:registry_occurrence) { create(:sbom_occurrence, :registry_occurrence, project: project) }
    let(:query) { pagination_query({ source_types: [:CONTAINER_SCANNING_FOR_REGISTRY] }) }

    it 'filters records based on the package manager name' do
      subject

      result = graphql_data_at(:project, :dependencies, :nodes)
      names = result.pluck('name')

      expect(names).to eq([registry_occurrence.name])
    end
  end
end
