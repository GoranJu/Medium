# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::DesiredConfigGenerator, :freeze_time, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  describe '#generate_desired_config' do
    let(:logger) { instance_double(Logger) }
    let(:user) { create(:user) }
    let_it_be(:agent, reload: true) { create(:ee_cluster_agent) }
    let(:desired_state) { RemoteDevelopment::WorkspaceOperations::States::RUNNING }
    let(:actual_state) { RemoteDevelopment::WorkspaceOperations::States::STOPPED }
    let(:started) { true }
    let(:include_all_resources) { false }
    let(:deployment_resource_version_from_agent) { workspace.deployment_resource_version }
    let(:network_policy_enabled) { true }
    let(:gitlab_workspaces_proxy_namespace) { 'gitlab-workspaces' }
    let(:max_resources_per_workspace) { {} }
    let(:default_resources_per_workspace_container) { {} }
    let(:image_pull_secrets) { [] }
    let(:workspaces_agent_config) do
      config = create(
        :workspaces_agent_config,
        agent: agent,
        image_pull_secrets: image_pull_secrets,
        default_resources_per_workspace_container: default_resources_per_workspace_container,
        max_resources_per_workspace: max_resources_per_workspace,
        network_policy_enabled: network_policy_enabled
      )
      agent.reload
      config
    end

    let(:workspace) do
      workspaces_agent_config
      create(
        :workspace,
        agent: agent,
        user: user,
        desired_state: desired_state,
        actual_state: actual_state
      )
    end

    let(:expected_config) do
      YAML.load_stream(
        create_config_to_apply(
          workspace: workspace,
          started: started,
          include_network_policy: workspace.workspaces_agent_config.network_policy_enabled,
          include_all_resources: include_all_resources,
          egress_ip_rules: workspace.workspaces_agent_config.network_policy_egress,
          max_resources_per_workspace: max_resources_per_workspace,
          default_resources_per_workspace_container: default_resources_per_workspace_container,
          allow_privilege_escalation: workspace.workspaces_agent_config.allow_privilege_escalation,
          use_kubernetes_user_namespaces: workspace.workspaces_agent_config.use_kubernetes_user_namespaces,
          default_runtime_class: workspace.workspaces_agent_config.default_runtime_class,
          agent_labels: workspace.workspaces_agent_config.labels,
          agent_annotations: workspace.workspaces_agent_config.annotations,
          image_pull_secrets: image_pull_secrets
        )
      )
    end

    subject(:workspace_resources) do
      described_class.generate_desired_config(
        workspace: workspace,
        include_all_resources: include_all_resources,
        logger: logger
      )
    end

    context 'when desired_state results in started=true' do
      it 'returns expected config with the replicas set to one' do
        expect(workspace_resources).to eq(expected_config)
        deployment = workspace_resources.find { |resource| resource.fetch('kind') == 'Deployment' }
        expect(deployment.dig('spec', 'replicas')).to eq(1)
      end
    end

    context 'when desired_state results in started=false' do
      let(:desired_state) { RemoteDevelopment::WorkspaceOperations::States::STOPPED }
      let(:started) { false }

      it 'returns expected config with the replicas set to zero' do
        expect(workspace_resources).to eq(expected_config)
        deployment = workspace_resources.find { |resource| resource.fetch('kind') == 'Deployment' }
        expect(deployment.dig('spec', 'replicas')).to eq(0)
      end
    end

    context 'when network policy is disabled for agent' do
      let(:network_policy_enabled) { false }

      it 'returns expected config without network policy' do
        expect(workspace_resources).to eq(expected_config)
        network_policy_resource = workspace_resources.select { |resource| resource.fetch('kind') == 'NetworkPolicy' }
        expect(network_policy_resource).to be_empty
      end
    end

    context 'when default_resources_per_workspace_container is not empty' do
      let(:default_resources_per_workspace_container) do
        { limits: { cpu: '1.5', memory: '786Mi' }, requests: { cpu: '0.6', memory: '512M' } }
      end

      it 'returns expected config with defaults for the container resources set' do
        expect(workspace_resources).to eq(expected_config)
        deployment = workspace_resources.find { |resource| resource.fetch('kind') == 'Deployment' }
        resources_per_workspace_container = deployment.dig('spec', 'template', 'spec',
          'containers').map do |container|
          container.fetch('resources')
        end
        resources = default_resources_per_workspace_container.deep_stringify_keys
        expect(resources_per_workspace_container).to all(eq resources)
      end
    end

    context 'when there are image-pull-secrets' do
      let(:image_pull_secrets) { [{ name: 'secret-name', namespace: 'secret-namespace' }] }
      let(:expected_image_pull_secrets_names) { [{ 'name' => 'secret-name' }] }

      it 'returns expected config with a service account resource configured' do
        expect(workspace_resources).to eq(expected_config)
        service_account_resource = workspace_resources.find { |resource| resource.fetch('kind') == 'ServiceAccount' }
        expect(service_account_resource.fetch('imagePullSecrets')).to eq(expected_image_pull_secrets_names)
      end
    end

    context 'when include_all_resources is true' do
      let(:include_all_resources) { true }

      context 'when max_resources_per_workspace is not empty' do
        let(:max_resources_per_workspace) do
          { limits: { cpu: '1.5', memory: '786Mi' }, requests: { cpu: '0.6', memory: '512Mi' } }
        end

        it 'returns expected config with resource quota set' do
          expect(workspace_resources).to eq(expected_config)
          resource_quota = workspace_resources.find { |resource| resource.fetch('kind') == 'ResourceQuota' }
          expect(resource_quota).not_to be_nil
        end
      end
    end

    context 'when DevfileParser returns empty array' do
      before do
        # rubocop:todo Layout/LineLength -- this line will not be too long once we rename RemoteDevelopment namespace to Workspaces
        allow(RemoteDevelopment::WorkspaceOperations::Reconcile::Output::DevfileParser).to receive(:get_all).and_return([])
        # rubocop:enable Layout/LineLength
      end

      it 'returns an empty array' do
        expect(workspace_resources).to eq([])
      end
    end
  end
end
