# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::ToolsInjectorComponentInserter, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:input_processed_devfile) { yaml_safe_load_symbolized(read_devfile_yaml("example.flattened-devfile.yaml")) }
  let(:expected_processed_devfile_name) { "example.tools-injector-inserted-devfile.yaml" }
  let(:expected_processed_devfile) { yaml_safe_load_symbolized(read_devfile_yaml(expected_processed_devfile_name)) }
  let(:tools_injector_image_from_settings) do
    "registry.gitlab.com/gitlab-org/workspaces/gitlab-workspaces-tools:5.0.0"
  end

  let(:settings) do
    {
      tools_injector_image: tools_injector_image_from_settings
    }
  end

  let(:vscode_extensions_gallery_metadata_enabled) { false }

  let(:context) do
    {
      processed_devfile: input_processed_devfile,
      tools_dir: "#{RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::WORKSPACE_DATA_VOLUME_PATH}/" \
        "#{RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::TOOLS_DIR_NAME}",
      settings: settings,
      vscode_extensions_gallery_metadata: { enabled: vscode_extensions_gallery_metadata_enabled }
    }
  end

  subject(:returned_value) do
    described_class.insert(context)
  end

  it 'inserts the tools injector component' do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end

  context 'when image is overridden in settings' do
    let(:tools_injector_image_from_settings) { 'my/awesome/image:42' }

    it 'uses image override' do
      image_from_processed_devfile = returned_value.dig(:processed_devfile, :components, 2, :container, :image)
      expect(image_from_processed_devfile).to eq(tools_injector_image_from_settings)
    end
  end
end
