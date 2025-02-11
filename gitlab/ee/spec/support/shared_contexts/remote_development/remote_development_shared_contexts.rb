# frozen_string_literal: true

# NOTE: These fixtures act somewhat as a "Golden Master" source of truth, so we do not use the constant values from
#       RemoteDevelopment::WorkspaceOperations::Create::Constants, but instead hardcode the corresponding values here.
RSpec.shared_context 'with remote development shared fixtures' do
  # rubocop:todo Metrics/ParameterLists, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- Cleanup as part of https://gitlab.com/gitlab-org/gitlab/-/issues/421687
  def create_workspace_agent_info_hash(
    workspace:,
    # NOTE: previous_actual_state is the actual state of the workspace IMMEDIATELY prior to the current state. We don't
    # simulate the situation where there may have been multiple transitions between reconciliation polling intervals.
    previous_actual_state:,
    current_actual_state:,
    # NOTE: workspace_exists is whether the workspace exists in the cluster at the time of the current_actual_state.
    workspace_exists:,
    workspace_variables_environment: nil,
    workspace_variables_file: nil,
    resource_version: '1',
    dns_zone: 'workspaces.localdev.me',
    error_details: nil
  )
    info = {
      name: workspace.name,
      namespace: workspace.namespace
    }

    if current_actual_state == RemoteDevelopment::WorkspaceOperations::States::TERMINATED
      info[:termination_progress] =
        RemoteDevelopment::WorkspaceOperations::States::TERMINATED
    end

    if current_actual_state == RemoteDevelopment::WorkspaceOperations::States::TERMINATING
      info[:termination_progress] =
        RemoteDevelopment::WorkspaceOperations::States::TERMINATING
    end

    if [
      RemoteDevelopment::WorkspaceOperations::States::TERMINATING,
      RemoteDevelopment::WorkspaceOperations::States::TERMINATED,
      RemoteDevelopment::WorkspaceOperations::States::UNKNOWN
    ].include?(current_actual_state)
      return info
    end

    # rubocop:disable Layout/LineLength -- Keep the individual 'in' cases on single lines for readability
    spec_replicas =
      if [RemoteDevelopment::WorkspaceOperations::States::STOPPED, RemoteDevelopment::WorkspaceOperations::States::STOPPING]
           .include?(current_actual_state)
        0
      else
        1
      end

    started = spec_replicas == 1

    # rubocop:todo Lint/DuplicateBranch -- Make this cop recognize that different arrays with different entries are not duplicates
    status =
      case [previous_actual_state, current_actual_state, workspace_exists]
      in [RemoteDevelopment::WorkspaceOperations::States::CREATION_REQUESTED, RemoteDevelopment::WorkspaceOperations::States::STARTING, _]
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:14:14Z"
            lastUpdateTime: "2023-04-10T10:14:14Z"
            message: Created new replica set "#{workspace.name}-hash"
            reason: NewReplicaSetCreated
            status: "True"
            type: Progressing
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::STARTING, false]
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:14:14Z"
            lastUpdateTime: "2023-04-10T10:14:14Z"
            message: Deployment does not have minimum availability.
            reason: MinimumReplicasUnavailable
            status: "False"
            type: Available
          - lastTransitionTime: "2023-04-10T10:14:14Z"
            lastUpdateTime: "2023-04-10T10:14:14Z"
            message: ReplicaSet "#{workspace.name}-hash" is progressing.
            reason: ReplicaSetUpdated
            status: "True"
            type: Progressing
          observedGeneration: 1
          replicas: 1
          unavailableReplicas: 1
          updatedReplicas: 1
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::RUNNING, false]
        <<~'YAML'
          availableReplicas: 1
          conditions:
          - lastTransitionTime: "2023-03-06T14:36:36Z"
            lastUpdateTime: "2023-03-06T14:36:36Z"
            message: Deployment has minimum availability.
            reason: MinimumReplicasAvailable
            status: "True"
            type: Available
          - lastTransitionTime: "2023-03-06T14:36:31Z"
            lastUpdateTime: "2023-03-06T14:36:36Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          readyReplicas: 1
          replicas: 1
          updatedReplicas: 1
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::FAILED, false]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::FAILED, RemoteDevelopment::WorkspaceOperations::States::STARTING, false]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::RUNNING, RemoteDevelopment::WorkspaceOperations::States::FAILED, _]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::RUNNING, RemoteDevelopment::WorkspaceOperations::States::STOPPING, _]
        <<~'YAML'
          availableReplicas: 1
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:35Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: Deployment has minimum availability.
            reason: MinimumReplicasAvailable
            status: "True"
            type: Available
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          observedGeneration: 1
          readyReplicas: 1
          replicas: 1
          updatedReplicas: 1
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STOPPING, RemoteDevelopment::WorkspaceOperations::States::STOPPED, _]
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:35Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: Deployment has minimum availability.
            reason: MinimumReplicasAvailable
            status: "True"
            type: Available
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          observedGeneration: 2
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STOPPED, RemoteDevelopment::WorkspaceOperations::States::STOPPED, true]
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: Deployment has minimum availability.
            reason: MinimumReplicasAvailable
            status: "True"
            type: Available
          - lastTransitionTime: "2023-04-10T10:49:59Z"
            lastUpdateTime: "2023-04-10T10:49:59Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          observedGeneration: 2
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STOPPING, RemoteDevelopment::WorkspaceOperations::States::FAILED, _]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::STOPPED, RemoteDevelopment::WorkspaceOperations::States::STARTING, _]
        # There are multiple state transitions inside kubernetes
        # Fields like `replicas`, `unavailableReplicas` and `updatedReplicas` eventually become present
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          - lastTransitionTime: "2023-04-10T10:49:59Z"
            lastUpdateTime: "2023-04-10T10:49:59Z"
            message: Deployment does not have minimum availability.
            reason: MinimumReplicasUnavailable
            status: "False"
            type: Available
          observedGeneration: 3
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STOPPED, RemoteDevelopment::WorkspaceOperations::States::FAILED, _]
        # Stopped workspace is terminated by the user which results in a Failed actual state.
        # e.g. could not unmount volume and terminate the workspace
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::STARTING, true]
        # There are multiple state transitions inside kubernetes
        # Fields like `replicas`, `unavailableReplicas` and `updatedReplicas` eventually become present
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          - lastTransitionTime: "2023-04-10T10:49:59Z"
            lastUpdateTime: "2023-04-10T10:49:59Z"
            message: Deployment does not have minimum availability.
            reason: MinimumReplicasUnavailable
            status: "False"
            type: Available
          observedGeneration: 3
          replicas: 1
          unavailableReplicas: 1
          updatedReplicas: 1
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::RUNNING, true]
        <<~'YAML'
          availableReplicas: 1
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          - lastTransitionTime: "2023-04-10T10:50:10Z"
            lastUpdateTime: "2023-04-10T10:50:10Z"
            message: Deployment has minimum availability.
            reason: MinimumReplicasAvailable
            status: "True"
            type: Available
          observedGeneration: 3
          readyReplicas: 1
          replicas: 1
          updatedReplicas: 1
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::FAILED, true]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::FAILED, RemoteDevelopment::WorkspaceOperations::States::STARTING, true]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::FAILED, RemoteDevelopment::WorkspaceOperations::States::STOPPING, _]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [_, RemoteDevelopment::WorkspaceOperations::States::FAILED, _]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
        # <<~'YAML'
        #   conditions:
        #     - lastTransitionTime: "2023-03-06T14:36:31Z"
        #       lastUpdateTime: "2023-03-08T11:16:35Z"
        #       message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
        #       reason: NewReplicaSetAvailable
        #       status: "True"
        #       type: Progressing
        #     - lastTransitionTime: "2023-03-08T11:16:55Z"
        #       lastUpdateTime: "2023-03-08T11:16:55Z"
        #       message: Deployment does not have minimum availability.
        #       reason: MinimumReplicasUnavailable
        #       status: "False"
        #       type: Available
        #     replicas: 1
        #     unavailableReplicas: 1
        #     updatedReplicas: 1
        # YAML
      else
        msg =
          'Unsupported state transition passed for create_workspace_agent_info_hash fixture creation: ' \
            "actual_state: #{previous_actual_state} -> #{current_actual_state}, " \
            "existing_workspace: #{workspace_exists}"
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError, msg
      end
    # rubocop:enable Lint/DuplicateBranch
    # rubocop:enable Layout/LineLength

    config_to_apply_yaml = create_config_to_apply(
      workspace: workspace,
      workspace_variables_environment: workspace_variables_environment,
      workspace_variables_file: workspace_variables_file,
      started: started,
      include_inventory: false,
      include_network_policy: false,
      include_all_resources: false,
      dns_zone: dns_zone
    )
    config_to_apply = YAML.load_stream(config_to_apply_yaml)
    latest_k8s_deployment_info = config_to_apply.detect { |config| config.fetch('kind') == 'Deployment' }
    latest_k8s_deployment_info['metadata']['resourceVersion'] = resource_version
    latest_k8s_deployment_info['status'] = YAML.safe_load(status)

    info[:latest_k8s_deployment_info] = latest_k8s_deployment_info
    info[:error_details] = error_details
    info.deep_symbolize_keys.to_h
  end

  # rubocop:enable Metrics/ParameterLists
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity
  def create_workspace_rails_info(
    name:,
    namespace:,
    desired_state:,
    actual_state:,
    deployment_resource_version: nil,
    config_to_apply: nil
  )
    {
      name: name,
      namespace: namespace,
      desired_state: desired_state,
      actual_state: actual_state,
      deployment_resource_version: deployment_resource_version,
      config_to_apply: config_to_apply
    }.compact
  end

  def create_config_to_apply(workspace:, **args)
    desired_config_generator_version = workspace.desired_config_generator_version

    method_name = "create_config_to_apply_v#{desired_config_generator_version}"
    send(method_name, workspace: workspace, **args)
  end

  # rubocop:disable Metrics/ParameterLists, Metrics/AbcSize -- Cleanup as part of https://gitlab.com/gitlab-org/gitlab/-/issues/421687
  def create_config_to_apply_v3(
    workspace:,
    started:,
    workspace_variables_environment: nil,
    workspace_variables_file: nil,
    include_inventory: true,
    include_network_policy: true,
    include_all_resources: false,
    dns_zone: 'workspaces.localdev.me',
    egress_ip_rules: [{
      allow: "0.0.0.0/0",
      except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
    }],
    max_resources_per_workspace: {},
    default_resources_per_workspace_container: {},
    allow_privilege_escalation: false,
    use_kubernetes_user_namespaces: false,
    default_runtime_class: "",
    agent_labels: {},
    agent_annotations: {},
    project_name: "test-project",
    namespace_path: "test-group",
    image_pull_secrets: [],
    core_resources_only: false
  )
    spec_replicas = started == true ? 1 : 0
    host_template_annotation = get_workspace_host_template_annotation(workspace.name, dns_zone)
    max_resources_per_workspace_sha256 = Digest::SHA256.hexdigest(
      max_resources_per_workspace.sort.to_h.to_s
    )
    extra_annotations = {
      "config.k8s.io/owning-inventory": "#{workspace.name}-workspace-inventory",
      "workspaces.gitlab.com/host-template": host_template_annotation.to_s,
      "workspaces.gitlab.com/id": workspace.id.to_s,
      "workspaces.gitlab.com/max-resources-per-workspace-sha256":
        max_resources_per_workspace_sha256
    }
    annotations = agent_annotations.merge(extra_annotations)
    extra_labels = {
      "agent.gitlab.com/id": workspace.agent.id.to_s
    }
    labels = agent_labels.merge(extra_labels)
    extra_secrets_annotations = {
      "config.k8s.io/owning-inventory": "#{workspace.name}-secrets-inventory",
      "workspaces.gitlab.com/host-template": host_template_annotation.to_s,
      "workspaces.gitlab.com/id": workspace.id.to_s,
      "workspaces.gitlab.com/max-resources-per-workspace-sha256":
        max_resources_per_workspace_sha256
    }
    secrets_annotations = agent_annotations.merge(extra_secrets_annotations)

    workspace_inventory = workspace_inventory(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      agent_id: workspace.agent.id
    )

    workspace_deployment = workspace_deployment(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: annotations,
      spec_replicas: spec_replicas,
      default_resources_per_workspace_container: default_resources_per_workspace_container,
      allow_privilege_escalation: allow_privilege_escalation,
      use_kubernetes_user_namespaces: use_kubernetes_user_namespaces,
      default_runtime_class: default_runtime_class
    )

    workspace_service = workspace_service(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: annotations
    )

    workspace_pvc = workspace_pvc(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: annotations
    )

    workspace_network_policy = workspace_network_policy(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: annotations,
      egress_ip_rules: egress_ip_rules
    )

    workspace_secrets_inventory = workspace_secrets_inventory(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      agent_id: workspace.agent.id
    )

    workspace_secret_environment = workspace_secret_environment(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: secrets_annotations,
      workspace_variables_environment: workspace_variables_environment || get_workspace_variables_environment(
        workspace_variables: workspace.workspace_variables
      )
    )

    workspace_secret_file = workspace_secret_file(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: secrets_annotations,
      workspace_variables_file: workspace_variables_file || get_workspace_variables_file(
        workspace_variables: workspace.workspace_variables
      )
    )

    workspace_resource_quota = workspace_resource_quota(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: annotations,
      max_resources_per_workspace: max_resources_per_workspace
    )

    workspace_service_account = workspace_service_account(
      name: workspace.name,
      namespace: workspace.namespace,
      image_pull_secrets: image_pull_secrets,
      labels: labels,
      annotations: annotations
    )

    resources = []
    resources << workspace_inventory if include_inventory
    resources << workspace_deployment
    resources << workspace_service
    resources << workspace_pvc

    unless core_resources_only
      resources << workspace_service_account
      resources << workspace_network_policy if include_network_policy

      if include_all_resources
        resources << workspace_resource_quota unless max_resources_per_workspace.blank?
        resources << workspace_secrets_inventory if include_inventory
        resources << workspace_secret_environment
        resources << workspace_secret_file
      end
    end

    resources.map do |resource|
      yaml = YAML.dump(Gitlab::Utils.deep_sort_hash(resource).deep_stringify_keys)
      yaml.gsub!('test-project', project_name)
      yaml.gsub!('test-group', namespace_path)
      yaml.gsub!('http://localhost/', root_url)
      yaml
    end.join
  end

  def workspace_inventory(workspace_name:, workspace_namespace:, agent_id:)
    {
      kind: "ConfigMap",
      apiVersion: "v1",
      metadata: {
        name: "#{workspace_name}-workspace-inventory",
        namespace: workspace_namespace.to_s,
        annotations: {},
        labels: {
          "cli-utils.sigs.k8s.io/inventory-id": "#{workspace_name}-workspace-inventory",
          "agent.gitlab.com/id": agent_id.to_s
        }
      }
    }
  end

  def workspace_deployment(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:,
    spec_replicas:,
    default_resources_per_workspace_container:,
    allow_privilege_escalation:,
    use_kubernetes_user_namespaces:,
    default_runtime_class:
  )
    variables_file_mount_path = RemoteDevelopment::WorkspaceOperations::WorkspaceOperationsConstants::VARIABLES_FILE_DIR
    container_security_context = {
      'allowPrivilegeEscalation' => allow_privilege_escalation,
      'privileged' => false,
      'runAsNonRoot' => true,
      'runAsUser' => RemoteDevelopment::WorkspaceOperations::Reconcile::ReconcileConstants::RUN_AS_USER
    }

    deployment = {
      apiVersion: "apps/v1",
      kind: "Deployment",
      metadata: {
        annotations: annotations,
        creationTimestamp: nil,
        labels: labels,
        name: workspace_name.to_s,
        namespace: workspace_namespace.to_s
      },
      spec: {
        replicas: spec_replicas,
        selector: {
          matchLabels: labels
        },
        strategy: {
          type: "Recreate"
        },
        template: {
          metadata: {
            annotations: annotations,
            creationTimestamp: nil,
            labels: labels,
            name: workspace_name.to_s,
            namespace: workspace_namespace.to_s
          },
          spec: {
            hostUsers: use_kubernetes_user_namespaces,
            runtimeClassName: default_runtime_class,
            containers: [
              {
                args: [
                  <<~"SH"
                    sshd_path=$(which sshd)
                    if [ -x "$sshd_path" ]; then
                      echo "Starting sshd on port ${GL_SSH_PORT}"
                      $sshd_path -D -p "${GL_SSH_PORT}" &
                    else
                      echo "'sshd' not found in path. Not starting SSH server."
                    fi
                    "${GL_TOOLS_DIR}/init_tools.sh"
                  SH
                ],
                command: %w[/bin/sh -c],
                env: [
                  {
                    name: "GL_TOOLS_DIR",
                    value: "/projects/.gl-tools"
                  },
                  {
                    name: "GL_EDITOR_LOG_LEVEL",
                    value: "info"
                  },
                  {
                    name: "GL_EDITOR_PORT",
                    value: "60001"
                  },
                  {
                    name: "GL_SSH_PORT",
                    value: "60022"
                  },
                  {
                    name: "GL_EDITOR_ENABLE_MARKETPLACE",
                    value: "false"
                  },
                  {
                    name: "PROJECTS_ROOT",
                    value: "/projects"
                  },
                  {
                    name: "PROJECT_SOURCE",
                    value: "/projects"
                  }
                ],
                image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                imagePullPolicy: "Always",
                name: "tooling-container",
                ports: [
                  {
                    containerPort: 60001,
                    name: "editor-server",
                    protocol: "TCP"
                  },
                  {
                    containerPort: 60022,
                    name: "ssh-server",
                    protocol: "TCP"
                  }
                ],
                resources: default_resources_per_workspace_container,
                volumeMounts: [
                  {
                    mountPath: "/projects",
                    name: "gl-workspace-data"
                  },
                  {
                    name: "gl-workspace-variables",
                    mountPath: variables_file_mount_path.to_s
                  }
                ],
                securityContext: container_security_context,
                envFrom: [
                  {
                    secretRef: {
                      name: "#{workspace_name}-env-var"
                    }
                  }
                ]
              },
              {
                env: [
                  {
                    name: "MYSQL_ROOT_PASSWORD",
                    value: "my-secret-pw"
                  },
                  {
                    name: "PROJECTS_ROOT",
                    value: "/projects"
                  },
                  {
                    name: "PROJECT_SOURCE",
                    value: "/projects"
                  }
                ],
                image: "mysql",
                imagePullPolicy: "Always",
                name: "database-container",
                resources: default_resources_per_workspace_container,
                volumeMounts: [
                  {
                    mountPath: "/projects",
                    name: "gl-workspace-data"
                  },
                  {
                    name: "gl-workspace-variables",
                    mountPath: variables_file_mount_path.to_s
                  }
                ],
                securityContext: container_security_context,
                envFrom: [
                  {
                    secretRef: {
                      name: "#{workspace_name}-env-var"
                    }
                  }
                ]
              }
            ],
            initContainers: [
              {
                args: [
                  <<~'SHELL'
                    if [ -f "/projects/.gl_project_cloning_successful" ];
                    then
                      echo "Project cloning was already successful";
                      exit 0;
                    fi
                    if [ -d "/projects/test-project" ];
                    then
                      echo "Removing unsuccessfully cloned project directory";
                      rm -rf "/projects/test-project";
                    fi
                    echo "Cloning project";
                    git clone --branch "master" "http://localhost/test-group/test-project.git" "/projects/test-project";
                    exit_code=$?
                    if [ "${exit_code}" -eq 0 ];
                    then
                      echo "Project cloning successful";
                      touch "/projects/.gl_project_cloning_successful";
                      echo "Updated file to indicate successful project cloning";
                      exit 0;
                    else
                      echo "Project cloning failed with exit code: ${exit_code}";
                      exit "${exit_code}";
                    fi
                  SHELL
                ],
                command: %w[/bin/sh -c],
                env: [
                  {
                    name: "PROJECTS_ROOT",
                    value: "/projects"
                  },
                  {
                    name: "PROJECT_SOURCE",
                    value: "/projects"
                  }
                ],
                image: "alpine/git:2.45.2",
                imagePullPolicy: "Always",
                name: "gl-project-cloner-gl-project-cloner-command-1",
                resources: {
                  limits: {
                    cpu: "500m",
                    memory: "512Mi"
                  },
                  requests: {
                    cpu: "100m",
                    memory: "256Mi"
                  }
                },
                volumeMounts: [
                  {
                    mountPath: "/projects",
                    name: "gl-workspace-data"
                  },
                  {
                    name: "gl-workspace-variables",
                    mountPath: variables_file_mount_path.to_s
                  }
                ],
                securityContext: container_security_context,
                envFrom: [
                  {
                    secretRef: {
                      name: "#{workspace_name}-env-var"
                    }
                  }
                ]
              },
              {
                env: [
                  {
                    name: "GL_TOOLS_DIR",
                    value: "/projects/.gl-tools"
                  },
                  {
                    name: "PROJECTS_ROOT",
                    value: "/projects"
                  },
                  {
                    name: "PROJECT_SOURCE",
                    value: "/projects"
                  }
                ],
                image: "registry.gitlab.com/gitlab-org/workspaces/gitlab-workspaces-tools:5.0.0",
                imagePullPolicy: "Always",
                name: "gl-tools-injector-gl-tools-injector-command-2",
                resources: {
                  limits: {
                    cpu: "500m",
                    memory: "512Mi"
                  },
                  requests: {
                    cpu: "100m",
                    memory: "256Mi"
                  }
                },
                volumeMounts: [
                  {
                    mountPath: "/projects",
                    name: "gl-workspace-data"
                  },
                  {
                    name: "gl-workspace-variables",
                    mountPath: variables_file_mount_path.to_s
                  }
                ],
                securityContext: container_security_context,
                envFrom: [
                  {
                    secretRef: {
                      name: "#{workspace_name}-env-var"
                    }
                  }
                ]
              }
            ],
            serviceAccountName: workspace_name.to_s,
            volumes: [
              {
                name: "gl-workspace-data",
                persistentVolumeClaim: {
                  claimName: "#{workspace_name}-gl-workspace-data"
                }
              },
              {
                name: "gl-workspace-variables",
                projected: {
                  defaultMode: 508,
                  sources: [
                    {
                      secret: {
                        name: "#{workspace_name}-file"
                      }
                    }
                  ]
                }
              }
            ],
            securityContext: {
              runAsNonRoot: true,
              runAsUser: RemoteDevelopment::WorkspaceOperations::Reconcile::ReconcileConstants::RUN_AS_USER,
              fsGroup: 0,
              fsGroupChangePolicy: "OnRootMismatch"
            }
          }
        }
      },
      status: {}
    }

    deployment[:spec][:template][:spec].delete(:runtimeClassName) if default_runtime_class.empty?
    deployment[:spec][:template][:spec].delete(:hostUsers) unless use_kubernetes_user_namespaces

    deployment
  end
  # rubocop:enable Metrics/ParameterLists, Metrics/AbcSize

  def workspace_service(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:
  )
    {
      apiVersion: "v1",
      kind: "Service",
      metadata: {
        annotations: annotations,
        creationTimestamp: nil,
        labels: labels,
        name: workspace_name.to_s,
        namespace: workspace_namespace.to_s
      },
      spec: {
        ports: [
          {
            name: "editor-server",
            port: 60001,
            targetPort: 60001
          },
          {
            name: "ssh-server",
            port: 60022,
            targetPort: 60022
          }
        ],
        selector: labels
      },
      status: {
        loadBalancer: {}
      }
    }
  end

  def workspace_pvc(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:
  )
    {
      apiVersion: "v1",
      kind: "PersistentVolumeClaim",
      metadata: {
        annotations: annotations,
        creationTimestamp: nil,
        labels: labels,
        name: "#{workspace_name}-gl-workspace-data",
        namespace: workspace_namespace.to_s
      },
      spec: {
        accessModes: [
          "ReadWriteOnce"
        ],
        resources: {
          requests: {
            storage: "50Gi"
          }
        }
      },
      status: {}
    }
  end

  def workspace_network_policy(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:,
    egress_ip_rules:
  )
    egress = [
      {
        ports: [{ port: 53, protocol: "TCP" }, { port: 53, protocol: "UDP" }],
        to: [
          {
            namespaceSelector: {
              matchLabels: {
                "kubernetes.io/metadata.name": "kube-system"
              }
            }
          }
        ]
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
        name: workspace_name.to_s,
        namespace: workspace_namespace.to_s
      },
      spec: {
        egress: egress,
        ingress: [
          {
            from: [
              {
                namespaceSelector: {
                  matchLabels: {
                    "kubernetes.io/metadata.name": "gitlab-workspaces"
                  }
                },
                podSelector: {
                  matchLabels: {
                    "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                  }
                }
              }
            ]
          }
        ],
        podSelector: {},
        policyTypes: %w[Ingress Egress]
      }
    }
  end

  def workspace_resource_quota(
    workspace_name:,
    workspace_namespace:,
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
        name: workspace_name.to_s,
        namespace: workspace_namespace.to_s
      },
      spec: {
        hard: {
          "limits.cpu": max_resources_per_workspace.dig(:limits, :cpu),
          "limits.memory": max_resources_per_workspace.dig(:limits, :memory),
          "requests.cpu": max_resources_per_workspace.dig(:requests, :cpu),
          "requests.memory": max_resources_per_workspace.dig(:requests, :memory)
        }
      }
    }
  end

  def workspace_service_account(
    name:,
    namespace:,
    image_pull_secrets:,
    labels:,
    annotations:
  )

    image_pull_secrets_names = image_pull_secrets.map { |secret| { name: secret.symbolize_keys.fetch(:name) } }
    {
      kind: 'ServiceAccount',
      apiVersion: 'v1',
      metadata: {
        name: name,
        namespace: namespace,
        annotations: annotations,
        labels: labels
      },
      automountServiceAccountToken: false,
      imagePullSecrets: image_pull_secrets_names
    }
  end

  def workspace_secrets_inventory(
    workspace_name:,
    workspace_namespace:,
    agent_id:
  )
    {
      kind: "ConfigMap",
      apiVersion: "v1",
      metadata: {
        name: "#{workspace_name}-secrets-inventory",
        namespace: workspace_namespace.to_s,
        annotations: {},
        labels: {
          "cli-utils.sigs.k8s.io/inventory-id": "#{workspace_name}-secrets-inventory",
          "agent.gitlab.com/id": agent_id.to_s
        }
      }
    }
  end

  def workspace_secret_environment(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:,
    workspace_variables_environment:
  )
    # TODO: figure out why there is flakiness in the order of the environment variables -- https://gitlab.com/gitlab-org/gitlab/-/issues/451934
    {
      kind: "Secret",
      apiVersion: "v1",
      metadata: {
        name: "#{workspace_name}-env-var",
        namespace: workspace_namespace.to_s,
        labels: labels,
        annotations: annotations
      },
      data: workspace_variables_environment.transform_values { |v| Base64.strict_encode64(v).to_s }
    }
  end

  def workspace_secret_file(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:,
    workspace_variables_file:
  )
    {
      kind: "Secret",
      apiVersion: "v1",
      metadata: {
        name: "#{workspace_name}-file",
        namespace: workspace_namespace.to_s,
        labels: labels,
        annotations: annotations
      },
      data: workspace_variables_file.transform_values { |v| Base64.strict_encode64(v).to_s }
    }
  end

  def get_workspace_variables_environment(workspace_variables:)
    workspace_variables.with_variable_type_environment.each_with_object({}) do |workspace_variable, hash|
      hash[workspace_variable.key] = workspace_variable.value
    end
  end

  def get_workspace_variables_file(workspace_variables:)
    workspace_variables.with_variable_type_file.each_with_object({}) do |workspace_variable, hash|
      hash[workspace_variable.key] = workspace_variable.value
    end
  end

  def get_workspace_host_template_annotation(workspace_name, dns_zone)
    "{{.port}}-#{workspace_name}.#{dns_zone}"
  end

  def get_workspace_host_template_environment(workspace_name, dns_zone)
    "${PORT}-#{workspace_name}.#{dns_zone}"
  end

  def yaml_safe_load_symbolized(yaml)
    YAML.safe_load(yaml).to_h.deep_symbolize_keys
  end

  def example_default_devfile_yaml
    read_devfile_yaml('example.default_devfile.yaml')
  end

  def example_devfile_yaml
    read_devfile_yaml('example.devfile.yaml')
  end

  def example_devfile
    yaml_safe_load_symbolized(example_devfile_yaml)
  end

  def example_flattened_devfile_yaml
    read_devfile_yaml("example.flattened-devfile.yaml")
  end

  def example_flattened_devfile
    yaml_safe_load_symbolized(example_flattened_devfile_yaml)
  end

  def example_processed_devfile_yaml(project_name: "test-project", namespace_path: "test-group")
    read_devfile_yaml("example.processed-devfile.yaml", project_name: project_name, namespace_path: namespace_path)
  end

  def example_processed_devfile(project_name: "test-project", namespace_path: "test-group")
    yaml_safe_load_symbolized(
      example_processed_devfile_yaml(project_name: project_name, namespace_path: namespace_path)
    )
  end

  def read_devfile_yaml(filename, project_name: "test-project", namespace_path: "test-group")
    devfile_contents = File.read(Rails.root.join('ee/spec/fixtures/remote_development', filename).to_s)
    devfile_contents.gsub!('http://localhost/', root_url)
    devfile_contents.gsub!('test-project', project_name)
    devfile_contents.gsub!('test-group', namespace_path)
    devfile_contents
  end

  def root_url
    # NOTE: Default to http://example.com/ if GitLab::Application is not defined. This allows this helper to be used
    #       from ee/spec/remote_development/fast_spec_helper.rb
    defined?(Gitlab::Application) ? Gitlab::Routing.url_helpers.root_url : 'https://example.com/'
  end
end
