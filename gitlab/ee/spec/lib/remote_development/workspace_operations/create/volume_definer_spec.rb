# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::VolumeDefiner, feature_category: :workspaces do
  let(:context) { { params: 1 } }
  let(:expected_tools_dir) do
    "#{RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::WORKSPACE_DATA_VOLUME_PATH}/" \
      "#{RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::TOOLS_DIR_NAME}"
  end

  subject(:returned_value) do
    described_class.define(context)
  end

  it "merges volume mount info to passed context" do
    expect(returned_value).to eq(
      {
        params: 1,
        tools_dir: expected_tools_dir,
        volume_mounts: {
          data_volume: {
            name: RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::WORKSPACE_DATA_VOLUME_NAME,
            path: "/projects"
          }
        }
      }
    )
  end
end
