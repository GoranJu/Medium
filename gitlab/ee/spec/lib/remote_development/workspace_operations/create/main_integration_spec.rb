# frozen_string_literal: true

require 'spec_helper'

# NOTE: This spec cannot use let_it_be because, because that doesn't work when using the `custom_repo` trait of
#       the project factory and subsequently modifying it, because it's a real on-disk repo at `tmp/tests/gitlab-test/`,
#       and any changes made to it are not reverted by let it be (even with reload). This means we also cannot use
#       these `let` declarations in a `before` context, so any mocking of them must occur in the examples themselves.

RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::Main, :freeze_time, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:user) { create(:user) }
  let(:group) { create(:group, name: 'test-group', developers: user) }
  let(:random_string) { 'abcdef' }
  let(:project_ref) { 'master' }
  let(:devfile_path) { '.devfile.yaml' }
  let(:devfile_fixture_name) { 'example.devfile.yaml' }
  let(:devfile_yaml) { read_devfile_yaml(devfile_fixture_name) }
  let(:expected_processed_devfile) { example_processed_devfile }
  let(:workspace_root) { '/projects' }
  let(:dns_zone) { 'dns.zone.me' }
  let(:variables) do
    [
      { key: 'VAR1', value: 'value 1', type: 'ENVIRONMENT' },
      { key: 'VAR2', value: 'value 2', type: 'ENVIRONMENT' }
    ]
  end

  let(:default_devfile_yaml) { example_default_devfile_yaml }

  let(:project) do
    files = devfile_path.nil? ? {} : { devfile_path => devfile_yaml }
    create(:project, :in_group, :custom_repo, path: 'test-project', files: files, namespace: group)
  end

  let(:agent) do
    create(:ee_cluster_agent, project: project, created_by_user: user)
  end

  let!(:workspaces_agent_config) { create(:workspaces_agent_config, agent: agent, dns_zone: dns_zone) }

  let(:params) do
    {
      agent: agent,
      user: user,
      project: project,
      desired_state: RemoteDevelopment::WorkspaceOperations::States::RUNNING,
      project_ref: project_ref,
      devfile_path: devfile_path,
      variables: variables
    }
  end

  let(:tools_injector_image_from_settings) do
    "registry.gitlab.com/gitlab-org/workspaces/gitlab-workspaces-tools:5.0.0"
  end

  let(:vscode_extensions_gallery) do
    {
      service_url: "https://open-vsx.org/vscode/gallery",
      item_url: "https://open-vsx.org/vscode/item",
      resource_url_template: "https://open-vsx.org/vscode/asset/{publisher}/{name}/{version}/Microsoft.VisualStudio.Code.WebResources/{path}"
    }
  end

  let(:settings) do
    {
      project_cloner_image: 'alpine/git:2.45.2',
      tools_injector_image: tools_injector_image_from_settings,
      default_devfile_yaml: default_devfile_yaml
    }
  end

  let(:vscode_extensions_gallery_metadata_enabled) { false }

  let(:context) do
    {
      user: user,
      params: params,
      settings: settings,
      vscode_extensions_gallery: vscode_extensions_gallery,
      vscode_extensions_gallery_metadata: { enabled: vscode_extensions_gallery_metadata_enabled }
    }
  end

  subject(:response) do
    described_class.main(context)
  end

  context 'when params are valid' do
    before do
      allow(project.repository).to receive_message_chain(:blob_at_branch, :data) { devfile_yaml }
      allow(SecureRandom).to receive(:alphanumeric) { random_string }
    end

    context 'when devfile is valid' do
      let(:expected_workspaces_agent_config_version) { 1 }

      it 'creates a new workspace and returns success', :aggregate_failures do
        # NOTE: This example is structured and ordered to give useful and informative error messages in case of failures
        expect { response }.to change { RemoteDevelopment::Workspace.count }.by(1)

        expect(response.fetch(:status)).to eq(:success)
        expect(response[:message]).to be_nil
        expect(response[:payload]).not_to be_nil
        expect(response[:payload][:workspace]).not_to be_nil

        workspace = response.fetch(:payload).fetch(:workspace)
        expect(workspace.user).to eq(user)
        expect(workspace.agent).to eq(agent)
        expect(workspace.desired_state).to eq(RemoteDevelopment::WorkspaceOperations::States::RUNNING)
        # noinspection RubyResolve
        expect(workspace.desired_state_updated_at).to eq(Time.current)
        expect(workspace.actual_state).to eq(RemoteDevelopment::WorkspaceOperations::States::CREATION_REQUESTED)
        expect(workspace.name).to eq("workspace-#{agent.id}-#{user.id}-#{random_string}")
        namespace_prefix = RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::NAMESPACE_PREFIX
        expect(workspace.namespace).to eq("#{namespace_prefix}-#{agent.id}-#{user.id}-#{random_string}")
        expect(workspace.workspaces_agent_config_version).to eq(expected_workspaces_agent_config_version)
        expect(workspace.url).to eq(URI::HTTPS.build({
          host: "60001-#{workspace.name}.#{dns_zone}",
          path: '/',
          query: {
            folder: "#{workspace_root}/#{project.path}"
          }.to_query
        }).to_s)
        # noinspection RubyResolve
        expect(workspace.devfile).to eq(devfile_yaml)

        actual_processed_devfile = yaml_safe_load_symbolized(workspace.processed_devfile)
        expect(actual_processed_devfile).to eq(expected_processed_devfile)

        variables.each do |variable|
          expect(
            RemoteDevelopment::WorkspaceVariable.where(
              workspace: workspace,
              key: variable[:key],
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES_FOR_GRAPHQL[variable[:type]]
            ).first&.value
          ).to eq(variable[:value])
        end
      end

      context 'with versioned workspaces_agent_configs behavior' do
        before do
          agent.unversioned_latest_workspaces_agent_config.touch
        end

        let(:expected_workspaces_agent_config_version) { 2 }

        it 'creates a new workspace with latest workspaces_agent_config version' do
          workspace = response.fetch(:payload).fetch(:workspace)
          expect(workspace.workspaces_agent_config_version).to eq(expected_workspaces_agent_config_version)
        end
      end
    end

    context 'when devfile_path is nil' do
      let(:devfile_path) { nil }

      it 'creates a new workspace using default_devfile_yaml from settings' do
        workspace = response.fetch(:payload).fetch(:workspace)

        expect(workspace.devfile).to eq(default_devfile_yaml)
      end
    end

    context 'when devfile is not valid', :aggregate_failures do
      let(:devfile_fixture_name) { 'example.invalid-components-entry-missing-devfile.yaml' }

      it 'does not create the workspace and returns error' do
        expect { response }.not_to change { RemoteDevelopment::Workspace.count }

        expect(response).to eq({
          status: :error,
          message: "Workspace create post flatten devfile validation failed: No components present in devfile",
          reason: :bad_request
        })
      end
    end
  end

  context 'when params are invalid' do
    context 'when devfile is not found' do
      let(:devfile_path) { 'not-found.yaml' }

      before do
        allow(project.repository).to receive(:blob_at_branch).and_return(nil)
      end

      it 'does not create the workspace and returns error', :aggregate_failures do
        expect { response }.not_to change { RemoteDevelopment::Workspace.count }

        expect(response).to eq({
          status: :error,
          message:
            "Workspace create devfile load failed: Devfile path '#{devfile_path}' at ref '#{project_ref}' " \
              "does not exist in the project repository", # rubocop:disable Layout/LineEndStringConcatenationIndentation -- RubyMine formatting conflict. See https://gitlab.com/gitlab-org/gitlab/-/issues/442626
          reason: :bad_request
        })
      end
    end

    context 'when agent has no associated config' do
      let(:workspaces_agent_config) { nil }
      let(:agent) { create(:cluster_agent, name: "007") }

      it 'does not create the workspace and returns error' do
        # sanity check on fixture
        expect(agent.unversioned_latest_workspaces_agent_config).to be_nil

        expect { response }.not_to change { RemoteDevelopment::Workspace.count }

        expect(response).to eq({
          status: :error,
          message: "Workspace create params validation failed: No WorkspacesAgentConfig found for agent '007'",
          reason: :bad_request
        })
      end
    end
  end

  context "when vscode_extensions_gallery_metadata Web IDE setting is disabled" do
    let(:tools_injector_image_from_settings) { 'my/awesome/image:42' }
    let(:vscode_extensions_gallery_metadata_enabled) { false }

    it 'uses image override' do
      tools_injector_component_name =
        RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::TOOLS_INJECTOR_COMPONENT_NAME
      workspace = response.fetch(:payload).fetch(:workspace)
      processed_devfile = yaml_safe_load_symbolized(workspace.processed_devfile)
      image_from_processed_devfile =
        processed_devfile.fetch(:components)
          .find { |component| component.fetch(:name) == tools_injector_component_name }
          .dig(:container, :image)
      expect(image_from_processed_devfile).to eq(tools_injector_image_from_settings)
    end
  end
end
