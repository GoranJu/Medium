# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::ProjectClonerComponentInserter, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:project_path) { "test-project" }
  let(:project) do
    http_url_to_repo = "#{root_url}test-group/#{project_path}.git"
    instance_double("Project", path: project_path, http_url_to_repo: http_url_to_repo) # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  end

  let(:input_processed_devfile) do
    yaml_safe_load_symbolized(read_devfile_yaml("example.main-container-updated-devfile.yaml"))
  end

  let(:expected_processed_devfile_name) { "example.project-cloner-inserted-devfile.yaml" }
  let(:expected_processed_devfile) { yaml_safe_load_symbolized(read_devfile_yaml(expected_processed_devfile_name)) }
  let(:context) do
    {
      params: {
        project: project,
        project_ref: "master"
      },
      processed_devfile: input_processed_devfile,
      volume_mounts: {
        data_volume: {
          path: "/projects"
        }
      },
      settings: {
        project_cloner_image: 'alpine/git:2.45.2'
      }
    }
  end

  subject(:returned_value) do
    described_class.insert(context)
  end

  it "injects the project cloner component" do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end
end
