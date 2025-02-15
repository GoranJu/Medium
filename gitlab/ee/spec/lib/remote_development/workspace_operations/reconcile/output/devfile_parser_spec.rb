# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::DevfileParser, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:dns_zone) { "workspaces.localdev.me" }
  let(:logger) { instance_double(Logger) }
  # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version of these models, so we can use fast_spec_helper.
  let(:user) { instance_double("User", name: "name", email: "name@example.com") }
  let(:agent) { instance_double("Clusters::Agent", id: 1) }
  let(:image_pull_secrets) { [{ name: 'secret-name', namespace: 'secret-namespace' }] }
  let(:workspaces_agent_config) do
    instance_double("RemoteDevelopment::WorkspacesAgentConfig", image_pull_secrets: image_pull_secrets)
  end

  let(:workspace) do
    instance_double(
      "RemoteDevelopment::Workspace",
      id: 1,
      name: "name",
      namespace: "namespace",
      deployment_resource_version: "1",
      desired_state: RemoteDevelopment::WorkspaceOperations::States::RUNNING,
      actual_state: RemoteDevelopment::WorkspaceOperations::States::STOPPED,
      processed_devfile: example_processed_devfile_yaml,
      user: user,
      agent: agent,
      workspaces_agent_config: workspaces_agent_config,
      desired_config_generator_version:
        ::RemoteDevelopment::WorkspaceOperations::DesiredConfigGeneratorVersion::LATEST_VERSION
    )
  end
  # rubocop:enable RSpec/VerifiedDoubleReference

  let(:processed_devfile_yaml) { example_processed_devfile_yaml }
  let(:domain_template) { "" }
  let(:egress_ip_rules) do
    [{
      allow: "0.0.0.0/0",
      except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
    }]
  end

  let(:max_resources_per_workspace) { {} }
  let(:default_resources_per_workspace_container) do
    { limits: { cpu: "1.5", memory: "786Mi" }, requests: { cpu: "0.6", memory: "512Mi" } }
  end

  let(:allow_privilege_escalation) { false }
  let(:use_kubernetes_user_namespaces) { false }
  let(:default_runtime_class) { "test" }
  let(:agent_labels) { { a: "1" } }
  let(:agent_annotations) { { b: "2" } }
  let(:labels) { {} }
  let(:annotations) { {} }

  let(:k8s_resources_params) do
    {
      name: workspace.name,
      namespace: workspace.namespace,
      replicas: 1,
      domain_template: domain_template,
      labels: labels,
      annotations: annotations,
      env_secret_names: ["#{workspace.name}-env-var"],
      file_secret_names: ["#{workspace.name}-file"],
      default_resources_per_workspace_container: default_resources_per_workspace_container,
      allow_privilege_escalation: allow_privilege_escalation,
      use_kubernetes_user_namespaces: use_kubernetes_user_namespaces,
      default_runtime_class: default_runtime_class,
      service_account_name: workspace.name
    }
  end

  let(:expected_workspace_resources) do
    YAML.load_stream(
      create_config_to_apply(
        workspace: workspace,
        workspace_variables_environment: {},
        workspace_variables_file: {},
        started: true,
        include_inventory: false,
        include_network_policy: false,
        include_all_resources: false,
        dns_zone: dns_zone,
        egress_ip_rules: egress_ip_rules,
        default_resources_per_workspace_container: default_resources_per_workspace_container,
        allow_privilege_escalation: allow_privilege_escalation,
        use_kubernetes_user_namespaces: use_kubernetes_user_namespaces,
        default_runtime_class: default_runtime_class,
        agent_labels: agent_labels,
        agent_annotations: agent_annotations,
        image_pull_secrets: image_pull_secrets,
        core_resources_only: true
      )
    )
  end

  subject(:k8s_resources_for_workspace_core) do
    described_class.get_all(
      processed_devfile: processed_devfile_yaml,
      k8s_resources_params: k8s_resources_params,
      logger: logger
    )
  end

  context "when the DevFile parser is successful in parsing k8s core resources" do
    let(:domain_template) { "{{.port}}-#{workspace.name}.#{dns_zone}" }
    let(:labels) { agent_labels.merge('agent.gitlab.com/id' => workspace.agent.id) }
    let(:annotations) do
      agent_annotations.merge({
        'config.k8s.io/owning-inventory' => "#{workspace.name}-workspace-inventory",
        'workspaces.gitlab.com/host-template' => domain_template,
        'workspaces.gitlab.com/id' => workspace.id,
        'workspaces.gitlab.com/max-resources-per-workspace-sha256' =>
          Digest::SHA256.hexdigest(max_resources_per_workspace.sort.to_h.to_s)
      })
    end

    context "when allow_privilege_escalation is true" do
      let(:allow_privilege_escalation) { true }

      it 'returns workspace_resources with allow_privilege_escalation set to true' do
        expect(k8s_resources_for_workspace_core).to eq(expected_workspace_resources)
        deployment = k8s_resources_for_workspace_core.find do |resource|
          resource.fetch('kind') == 'Deployment'
        end.to_h

        container_privilege_escalation = deployment.dig('spec', 'template', 'spec', 'containers').map do |container|
          container.dig('securityContext', 'allowPrivilegeEscalation')
        end

        init_container_privilege_escalation = deployment.dig('spec', 'template', 'spec',
          'initContainers').map do |container|
          container.dig('securityContext', 'allowPrivilegeEscalation')
        end

        all_containers_privilege_escalation = init_container_privilege_escalation + container_privilege_escalation

        expect(all_containers_privilege_escalation).to all(be true)
      end
    end

    context "when use_kubernetes_user_namespaces is true" do
      let(:use_kubernetes_user_namespaces) { true }

      it 'returns workspace_resources with hostUsers set to true' do
        expect(k8s_resources_for_workspace_core).to eq(expected_workspace_resources)
        deployment = k8s_resources_for_workspace_core.find do |resource|
          resource.fetch('kind') == 'Deployment'
        end.to_h
        expect(deployment.dig('spec', 'template', 'spec', 'hostUsers')).to be(true)
      end
    end
  end

  context 'when a runtime error is raised' do
    RSpec.shared_examples 'when a runtime error is raised' do
      before do
        allow(Devfile::Parser).to receive(:get_all).and_raise(error_type.new("some error"))
      end

      it 'logs the error' do
        expect(logger).to receive(:warn).with(
          message: "#{error_type}: #{error_message}",
          error_type: 'reconcile_devfile_parser_error',
          workspace_name: workspace.name,
          workspace_namespace: workspace.namespace,
          devfile_parser_error: "some error"
        )
        expect(k8s_resources_for_workspace_core).to eq([])
      end
    end

    let(:processed_devfile_yaml) { "" }

    context "when Devfile::CliError is raised" do
      let(:error_type) { Devfile::CliError }
      let(:error_message) do
        "A non zero return code was observed when invoking the devfile CLI executable from the devfile gem."
      end

      it_behaves_like 'when a runtime error is raised'
    end

    context "when StandardError is raised" do
      let(:error_type) { StandardError }
      let(:error_message) do
        <<~MSG.squish
        An unrecoverable error occurred when invoking the devfile gem, this may hint that a gem with a wrong
        architecture is being used.
        MSG
      end

      it_behaves_like 'when a runtime error is raised'
    end
  end
end
