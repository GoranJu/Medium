# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::VolumeComponentInserter, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:input_processed_devfile) do
    yaml_safe_load_symbolized(read_devfile_yaml("example.project-cloner-inserted-devfile.yaml"))
  end

  let(:expected_processed_devfile_name) { "example.processed-devfile.yaml" }
  let(:expected_processed_devfile) { yaml_safe_load_symbolized(read_devfile_yaml(expected_processed_devfile_name)) }
  let(:volume_name) { RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::WORKSPACE_DATA_VOLUME_NAME }
  let(:context) do
    {
      processed_devfile: input_processed_devfile,
      volume_mounts: {
        data_volume: {
          name: volume_name,
          path: "/projects"
        }
      }
    }
  end

  subject(:returned_value) do
    described_class.insert(context)
  end

  it "injects the workspace volume component" do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end
end
