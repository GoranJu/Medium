# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      module Output
        class DesiredConfigGenerator
          include States

          # @param [RemoteDevelopment::WorkspaceOperations::Workspace] workspace
          # @param [Boolean] include_all_resources
          # @param [RemoteDevelopment::Logger] logger
          # @return [Array<Hash>]
          def self.generate_desired_config(workspace:, include_all_resources:, logger:)
            desired_config = []
            workspaces_agent_config = workspace.workspaces_agent_config
            # NOTE: update env_secret_name to "#{workspace.name}-environment". This is to ensure naming consistency.
            # Changing it now would require migration from old config version to a new one.
            # Update this when a new desired config generator is created for some other reason.
            env_secret_name = "#{workspace.name}-env-var"
            file_secret_name = "#{workspace.name}-file"
            domain_template = get_domain_template_annotation(
              name: workspace.name,
              dns_zone: workspaces_agent_config.dns_zone
            )
            inventory_name = "#{workspace.name}-workspace-inventory"

            labels, annotations = get_merged_labels_and_annotations(
              agent_labels: workspaces_agent_config.labels,
              agent_annotations: workspaces_agent_config.annotations,
              agent_id: workspace.agent.id,
              domain_template: domain_template,
              owning_inventory: inventory_name,
              workspace_id: workspace.id,
              max_resources_per_workspace: workspaces_agent_config.max_resources_per_workspace.deep_symbolize_keys
            )

            k8s_inventory_for_workspace_core = get_inventory_config_map(
              name: inventory_name,
              namespace: workspace.namespace,
              agent_labels: workspaces_agent_config.labels,
              agent_annotations: workspaces_agent_config.annotations,
              agent_id: workspace.agent.id
            )

            k8s_resources_params = {
              name: workspace.name,
              namespace: workspace.namespace,
              replicas: get_workspace_replicas(desired_state: workspace.desired_state),
              domain_template: domain_template,
              labels: labels,
              annotations: annotations,
              env_secret_names: [env_secret_name],
              file_secret_names: [file_secret_name],
              service_account_name: workspace.name,
              default_resources_per_workspace_container: workspaces_agent_config
                .default_resources_per_workspace_container
                .deep_symbolize_keys,
              allow_privilege_escalation: workspaces_agent_config.allow_privilege_escalation,
              use_kubernetes_user_namespaces: workspaces_agent_config.use_kubernetes_user_namespaces,
              default_runtime_class: workspaces_agent_config.default_runtime_class
            }

            # TODO: https://gitlab.com/groups/gitlab-org/-/epics/12225 - handle error
            k8s_resources_for_workspace_core = DevfileParser.get_all(
              processed_devfile: workspace.processed_devfile,
              k8s_resources_params: k8s_resources_params,
              logger: logger
            )
            # If we got no resources back from the devfile parser, this indicates some error was encountered in parsing
            # the processed_devfile. So we return an empty array which will result in no updates being applied by the
            # agent. We should not continue on and try to add anything else to the resources, as this would result
            # in an invalid configuration being applied to the cluster.
            return [] if k8s_resources_for_workspace_core.empty?

            desired_config.append(k8s_inventory_for_workspace_core, *k8s_resources_for_workspace_core)

            workspace_service_account_definition = get_image_pull_secrets_service_account(
              name: workspace.name,
              namespace: workspace.namespace,
              image_pull_secrets: workspaces_agent_config.image_pull_secrets,
              labels: labels,
              annotations: annotations
            )
            desired_config.append(workspace_service_account_definition)

            if workspaces_agent_config.network_policy_enabled
              network_policy = get_network_policy(
                name: workspace.name,
                namespace: workspace.namespace,
                labels: labels,
                annotations: annotations,
                gitlab_workspaces_proxy_namespace: workspaces_agent_config.gitlab_workspaces_proxy_namespace,
                egress_ip_rules: workspaces_agent_config.network_policy_egress
              )
              desired_config.append(network_policy)
            end

            return desired_config unless include_all_resources

            desired_config + get_extra_k8s_resources(
              workspace: workspace,
              labels: labels,
              annotations: annotations,
              env_secret_name: env_secret_name,
              file_secret_name: file_secret_name
            )
          end

          # @param [RemoteDevelopment::WorkspaceOperations::Workspace] workspace
          # @param [Hash<String, String>] labels
          # @param [Hash<String, String>] annotations
          # @param [String] env_secret_name
          # @param [String] file_secret_name
          # @param [Hash] desired_config
          # @return [Array<(Hash)>]
          def self.get_extra_k8s_resources(
            workspace:,
            labels:,
            annotations:,
            env_secret_name:,
            file_secret_name:
          )

            workspaces_agent_config = workspace.workspaces_agent_config
            agent_annotations = workspaces_agent_config.annotations
            agent_labels = workspaces_agent_config.labels
            max_resources_per_workspace = workspaces_agent_config.max_resources_per_workspace.deep_symbolize_keys
            extra_config = []

            unless max_resources_per_workspace.blank?
              k8s_resource_quota = get_resource_quota(
                name: workspace.name,
                namespace: workspace.namespace,
                labels: labels,
                annotations: annotations,
                max_resources_per_workspace: max_resources_per_workspace
              )
              extra_config.append(k8s_resource_quota)
            end

            k8s_resources_for_secrets = get_k8s_resources_for_secrets(
              workspace: workspace,
              agent_labels: agent_labels,
              agent_annotations: agent_annotations,
              env_secret_name: env_secret_name,
              file_secret_name: file_secret_name,
              max_resources_per_workspace: max_resources_per_workspace
            )
            extra_config.append(*k8s_resources_for_secrets)

            extra_config
          end

          # @param [RemoteDevelopment::WorkspaceOperations::Workspace] workspace
          # @param [Hash<String, String>] agent_labels
          # @param [Hash<String, String>] agent_annotations
          # @param [String] env_secret_name
          # @param [String] file_secret_name
          # @param [String] env_secret_name
          # @param [String] file_secret_name
          # @param [Hash] max_resources_per_workspace
          # @return [Array<(Hash)>]
          def self.get_k8s_resources_for_secrets(
            workspace:,
            agent_labels:,
            agent_annotations:,
            env_secret_name:,
            file_secret_name:,
            max_resources_per_workspace:
          )
            inventory_name = "#{workspace.name}-secrets-inventory"
            domain_template = get_domain_template_annotation(
              name: workspace.name,
              dns_zone: workspace.workspaces_agent_config.dns_zone
            )
            labels, annotations = get_merged_labels_and_annotations(
              agent_labels: agent_labels,
              agent_annotations: agent_annotations,
              agent_id: workspace.agent.id,
              domain_template: domain_template,
              owning_inventory: inventory_name,
              workspace_id: workspace.id,
              max_resources_per_workspace: max_resources_per_workspace
            )

            k8s_inventory = get_inventory_config_map(
              name: inventory_name,
              agent_labels: agent_labels,
              agent_annotations: agent_annotations,
              namespace: workspace.namespace,
              agent_id: workspace.agent.id
            )

            data_for_environment = workspace.workspace_variables.with_variable_type_environment
            data_for_environment = data_for_environment.each_with_object({}) do |workspace_variable, hash|
              hash[workspace_variable.key] = workspace_variable.value
            end
            k8s_secret_for_environment = get_secret(
              name: env_secret_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: annotations,
              data: data_for_environment
            )

            data_for_file = workspace.workspace_variables.with_variable_type_file
            data_for_file = data_for_file.each_with_object({}) do |workspace_variable, hash|
              hash[workspace_variable.key] = workspace_variable.value
            end
            k8s_secret_for_file = get_secret(
              name: file_secret_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: annotations,
              data: data_for_file
            )

            [k8s_inventory, k8s_secret_for_environment, k8s_secret_for_file]
          end

          # @param [String] desired_state
          # @return [Integer]
          def self.get_workspace_replicas(desired_state:)
            return 1 if [
              CREATION_REQUESTED,
              RUNNING
            ].include?(desired_state)

            0
          end

          # @param [String] name
          # @param [String] namespace
          # @param [Hash<String, String>] agent_labels
          # @param [Hash<String, String>] agent_annotations
          # @param [Integer] agent_id
          # @return [Hash]
          def self.get_inventory_config_map(name:, namespace:, agent_labels:, agent_annotations:, agent_id:)
            extra_labels = {
              'cli-utils.sigs.k8s.io/inventory-id' => name,
              'agent.gitlab.com/id' => agent_id.to_s
            }
            labels = agent_labels.merge(extra_labels)
            {
              kind: 'ConfigMap',
              apiVersion: 'v1',
              metadata: {
                name: name,
                namespace: namespace,
                labels: labels,
                annotations: agent_annotations
              }
            }.deep_stringify_keys.to_h
          end

          # @param [Hash<String, String>] agent_labels
          # @param [Hash<String, String>] agent_annotations
          # @param [Integer] agent_id
          # @param [String] domain_template
          # @param [String] owning_inventory
          # @param [String] object_type
          # @param [Integer] workspace_id
          # @param [Hash] max_resources_per_workspace
          # @return [Array<Hash, Hash>]
          def self.get_merged_labels_and_annotations(
            agent_labels:,
            agent_annotations:,
            agent_id:,
            domain_template:,
            owning_inventory:,
            workspace_id:,
            max_resources_per_workspace:
          )
            extra_labels = {
              'agent.gitlab.com/id' => agent_id.to_s
            }
            labels = agent_labels.merge(extra_labels)
            extra_annotations = {
              'config.k8s.io/owning-inventory' => owning_inventory.to_s,
              'workspaces.gitlab.com/host-template' => domain_template.to_s,
              'workspaces.gitlab.com/id' => workspace_id.to_s,
              'workspaces.gitlab.com/max-resources-per-workspace-sha256' =>
                Digest::SHA256.hexdigest(max_resources_per_workspace.sort.to_h.to_s)
            }
            annotations = agent_annotations.merge(extra_annotations)
            [labels, annotations]
          end

          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Hash] data
          # @return [Hash]
          def self.get_secret(name:, namespace:, labels:, annotations:, data:)
            {
              kind: 'Secret',
              apiVersion: 'v1',
              metadata: {
                name: name,
                namespace: namespace,
                labels: labels,
                annotations: annotations
              },
              data: data.transform_values { |v| Base64.strict_encode64(v) }
            }.deep_stringify_keys.to_h
          end

          # @param [String] name
          # @param [String] dns_zone
          # @return [String]
          def self.get_domain_template_annotation(name:, dns_zone:)
            "{{.port}}-#{name}.#{dns_zone}"
          end

          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [string] gitlab_workspaces_proxy_namespace
          # @param [Array<Hash>] egress_ip_rules
          # @return [Hash]
          def self.get_network_policy(
            name:,
            namespace:,
            labels:,
            annotations:,
            gitlab_workspaces_proxy_namespace:,
            egress_ip_rules:
          )
            policy_types = [
              - "Ingress",
              - "Egress"
            ]

            proxy_namespace_selector = {
              matchLabels: {
                "kubernetes.io/metadata.name": gitlab_workspaces_proxy_namespace
              }
            }
            proxy_pod_selector = {
              matchLabels: {
                "app.kubernetes.io/name": "gitlab-workspaces-proxy"
              }
            }
            ingress = [{ from: [{ namespaceSelector: proxy_namespace_selector, podSelector: proxy_pod_selector }] }]

            kube_system_namespace_selector = {
              matchLabels: {
                "kubernetes.io/metadata.name": "kube-system"
              }
            }
            egress = [
              {
                ports: [{ port: 53, protocol: "TCP" }, { port: 53, protocol: "UDP" }],
                to: [{ namespaceSelector: kube_system_namespace_selector }]
              }
            ]
            egress_ip_rules.each do |egress_rule|
              symbolized_egress_rule = egress_rule.deep_symbolize_keys
              egress.append(
                { to: [{ ipBlock: { cidr: symbolized_egress_rule[:allow], except: symbolized_egress_rule[:except] } }] }
              )
            end

            {
              apiVersion: "networking.k8s.io/v1",
              kind: "NetworkPolicy",
              metadata: {
                annotations: annotations,
                labels: labels,
                name: name,
                namespace: namespace
              },
              spec: {
                egress: egress,
                ingress: ingress,
                podSelector: {},
                policyTypes: policy_types
              }
            }.deep_stringify_keys.to_h
          end

          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Hash] max_resources_per_workspace
          # @return [Hash]
          def self.get_resource_quota(
            name:,
            namespace:,
            labels:,
            annotations:,
            max_resources_per_workspace:
          )
            {
              apiVersion: "v1",
              kind: "ResourceQuota",
              metadata: {
                annotations: annotations,
                labels: labels,
                name: name,
                namespace: namespace
              },
              spec: {
                hard: {
                  "limits.cpu": max_resources_per_workspace.dig(:limits, :cpu),
                  "limits.memory": max_resources_per_workspace.dig(:limits, :memory),
                  "requests.cpu": max_resources_per_workspace.dig(:requests, :cpu),
                  "requests.memory": max_resources_per_workspace.dig(:requests, :memory)
                }
              }
            }.deep_stringify_keys.to_h
          end

          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Array] image_pull_secrets
          # @return [Hash]
          def self.get_image_pull_secrets_service_account(name:, namespace:, labels:, annotations:, image_pull_secrets:)
            image_pull_secrets_names = image_pull_secrets.map { |secret| { name: secret.fetch('name') } }
            {
              apiVersion: 'v1',
              kind: 'ServiceAccount',
              metadata: {
                name: name,
                namespace: namespace,
                annotations: annotations,
                labels: labels
              },
              automountServiceAccountToken: false,
              imagePullSecrets: image_pull_secrets_names
            }.deep_stringify_keys.to_h
          end
        end
      end
    end
  end
end
