# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/helpers/remote_development/integration_spec_helpers"

# rubocop:disable RSpec/MultipleMemoizedHelpers -- this is an integration test, it has a lot of fixtures, but only one example, so we don't need let_it_be
RSpec.describe "Full workspaces integration request spec", :freeze_time, feature_category: :workspaces do
  include GraphqlHelpers
  include RemoteDevelopment::IntegrationSpecHelpers
  include_context "with remote development shared fixtures"

  let(:states) { ::RemoteDevelopment::WorkspaceOperations::States }
  let(:agent_admin_user) { create(:user, name: "Agent Admin User") }
  # Agent setup
  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::Kas::SECRET_LENGTH) }
  let(:agent_token) { create(:cluster_agent_token, agent: agent) }
  let(:workspaces_agents_config_query) do
    <<~GRAPHQL
      query {
          namespace(fullPath: "#{common_parent_namespace.full_path}") {
            remoteDevelopmentClusterAgents(filter: AVAILABLE) {
              nodes {
                id
                workspacesAgentConfig {
                  id
                  projectId
                  enabled
                  gitlabWorkspacesProxyNamespace
                  networkPolicyEnabled
                  dnsZone
                  workspacesPerUserQuota
                  workspacesQuota
                }
              }
            }
          }
        }
    GRAPHQL
  end

  let(:gitlab_workspaces_proxy_namespace) { "gitlab-workspaces" }
  let(:dns_zone) { "integration-spec-workspaces.localdev.me" }
  let(:workspaces_per_user_quota) { 20 }
  let(:workspaces_quota) { 100 }
  let(:user) { create(:user, name: "Workspaces User", email: "workspaces-user@example.org") }
  let(:current_user) { user }
  let(:common_parent_namespace_name) { "common-parent-group" }
  let(:common_parent_namespace) { create(:group, name: common_parent_namespace_name, owners: agent_admin_user) }
  let(:agent_project_namespace) do
    create(:group, name: "agent-project-group", parent: common_parent_namespace)
  end

  let(:workspace_project_namespace_name) { "workspace-project-group" }
  let(:workspace_project_namespace) do
    create(:group, name: workspace_project_namespace_name, parent: common_parent_namespace)
  end

  let(:workspace_project_name) { "workspace-project" }
  let(:workspace_namespace_path) { "#{common_parent_namespace_name}/#{workspace_project_namespace_name}" }
  let(:random_string) { "abcdef" }
  let(:project_ref) { "master" }
  let(:devfile_path) { ".devfile.yaml" }
  let(:devfile_fixture_name) { "example.devfile.yaml" }
  let(:devfile_yaml) do
    read_devfile_yaml(
      devfile_fixture_name,
      namespace_path: "#{common_parent_namespace_name}/#{workspace_project_namespace_name}",
      project_name: workspace_project_name
    )
  end

  let(:expected_processed_devfile_yaml) do
    example_processed_devfile_yaml(
      namespace_path: "#{common_parent_namespace_name}/#{workspace_project_namespace_name}",
      project_name: workspace_project_name
    )
  end

  let(:expected_processed_devfile) { yaml_safe_load_symbolized(expected_processed_devfile_yaml) }
  let(:workspace_root) { "/projects" }
  let(:user_provided_variables) do
    [
      { key: "VAR1", value: "value 1", type: :environment },
      { key: "VAR2", value: "value 2", type: :environment }
    ]
  end

  let(:expected_internal_variables) do
    # rubocop:disable Layout/LineLength -- keep them on one line for easier readability and editability
    [
      { key: "GIT_CONFIG_COUNT", type: :environment, value: "3" },
      { key: "GIT_CONFIG_KEY_0", type: :environment, value: "credential.helper" },
      { key: "GIT_CONFIG_KEY_1", type: :environment, value: "user.name" },
      { key: "GIT_CONFIG_KEY_2", type: :environment, value: "user.email" },
      { key: "GIT_CONFIG_VALUE_0", type: :environment, value: "/.workspace-data/variables/file/gl_git_credential_store.sh" },
      { key: "GIT_CONFIG_VALUE_1", type: :environment, value: "Workspaces User" },
      { key: "GIT_CONFIG_VALUE_2", type: :environment, value: "workspaces-user@example.org" },
      { key: "GL_EDITOR_EXTENSIONS_GALLERY_ITEM_URL", type: :environment, value: "https://open-vsx.org/vscode/item" },
      { key: "GL_EDITOR_EXTENSIONS_GALLERY_RESOURCE_URL_TEMPLATE", type: :environment, value: "https://open-vsx.org/vscode/asset/{publisher}/{name}/{version}/Microsoft.VisualStudio.Code.WebResources/{path}" },
      { key: "GL_EDITOR_EXTENSIONS_GALLERY_SERVICE_URL", type: :environment, value: "https://open-vsx.org/vscode/gallery" },
      { key: "GL_GIT_CREDENTIAL_STORE_SCRIPT_FILE", type: :environment, value: "/.workspace-data/variables/file/gl_git_credential_store.sh" },
      { key: "GL_TOKEN_FILE_PATH", type: :environment, value: "/.workspace-data/variables/file/gl_token" },
      { key: "GL_WORKSPACE_DOMAIN_TEMPLATE", type: :environment, value: "${PORT}-workspace-#{agent.id}-#{user.id}-#{random_string}.#{dns_zone}" },
      { key: "GITLAB_WORKFLOW_INSTANCE_URL", type: :environment, value: Gitlab::Routing.url_helpers.root_url },
      { key: "GITLAB_WORKFLOW_TOKEN_FILE", type: :environment, value: "/.workspace-data/variables/file/gl_token" },
      { key: "gl_git_credential_store.sh", type: :file, value: RemoteDevelopment::Files::WORKSPACE_VARIABLES_GIT_CREDENTIAL_STORE_SCRIPT },
      { key: "gl_token", type: :file, value: /glpat-.+/ }
    ]
    # rubocop:enable Layout/LineLength
  end

  let(:workspace_project) do
    files = { devfile_path => devfile_yaml }
    create(:project, :in_group, :custom_repo, path: workspace_project_name, files: files,
      namespace: workspace_project_namespace, developers: user)
  end

  let(:image_pull_secrets) { [{ name: 'secret-name', namespace: 'secret-namespace' }] }

  let(:agent_config_file_hash) do
    {
      remote_development: {
        enabled: true,
        dns_zone: dns_zone,
        workspaces_per_user_quota: workspaces_per_user_quota,
        workspaces_quota: workspaces_quota,
        image_pull_secrets: image_pull_secrets
      }
    }
  end

  let(:agent_project) do
    create(:project, :in_group, path: "agent-project", namespace: agent_project_namespace, developers: user)
  end

  let(:agent) do
    create(:ee_cluster_agent, project: agent_project, created_by_user: agent_admin_user, project_id: agent_project.id)
  end

  def do_create_workspaces_agent_config
    # Perform an agent update post which will cause a workspaces_agent_config record to be created
    # based on the cluster agent's config file.

    params = {
      agent_id: agent.id,
      agent_config: agent_config_file_hash
    }

    jwt_token = JWT.encode(
      { "iss" => Gitlab::Kas::JWT_ISSUER, 'aud' => Gitlab::Kas::JWT_AUDIENCE },
      Gitlab::Kas.secret,
      "HS256"
    )
    agent_token_headers = {
      "Authorization" => "Bearer #{agent_token.token}",
      Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => jwt_token
    }
    agent_configuration_url = api("/internal/kubernetes/agent_configuration", personal_access_token: agent_token)

    post agent_configuration_url, params: params, headers: agent_token_headers, as: :json

    # The internal kubernetes agent_configuration API endpoint does not return any response,
    # it only returns 204 No Content.
    expect(response).to have_gitlab_http_status(:no_content)

    workspaces_agent_config = RemoteDevelopment::WorkspacesAgentConfig.find_by_cluster_agent_id(agent.id)

    # Get the agent config via the GraphQL API to verify it was created correctly
    get_graphql(workspaces_agents_config_query, current_user: agent_admin_user)
    expected_agent_config =
      {
        "id" => "gid://gitlab/RemoteDevelopment::WorkspacesAgentConfig/#{workspaces_agent_config.id}",
        "projectId" => agent_project.id.to_s,
        "enabled" => true,
        "gitlabWorkspacesProxyNamespace" => "gitlab-workspaces",
        "networkPolicyEnabled" => true,
        "dnsZone" => dns_zone,
        "workspacesPerUserQuota" => workspaces_per_user_quota,
        "workspacesQuota" => workspaces_quota
      }
    expect(
      graphql_data_at(:namespace, :remoteDevelopmentClusterAgents, :nodes, 0, :workspacesAgentConfig)
    ).to eq(expected_agent_config)
  end

  def do_create_mapping
    namespace_create_remote_development_cluster_agent_mapping_create_mutation_args =
      {
        namespace_id: common_parent_namespace.to_global_id.to_s,
        cluster_agent_id: agent.to_global_id.to_s
      }
    do_graphql_mutation_post(
      name: :namespace_create_remote_development_cluster_agent_mapping,
      input: namespace_create_remote_development_cluster_agent_mapping_create_mutation_args,
      user: agent_admin_user
    )
  end

  # rubocop:disable Metrics/AbcSize -- We want this to stay a single method
  def do_create_workspace
    # FETCH THE AGENT CONFIG VIA THE GRAPHQL API, SO WE CAN USE ITS VALUES WHEN CREATING WORKSPACE
    cluster_agent_gid = "gid://gitlab/Clusters::Agent/#{agent.id}"

    create_mutation_response = do_graphql_mutation_post(
      name: :workspace_create,
      input: workspace_create_mutation_args(cluster_agent_gid),
      user: user
    )

    workspace_gid = create_mutation_response.fetch("workspace").fetch("id")
    workspace_id = GitlabSchema.parse_gid(workspace_gid, expected_type: ::RemoteDevelopment::Workspace).model_id
    workspace = ::RemoteDevelopment::Workspace.find(workspace_id)

    # NOTE: Where possible, avoid explicit assertions here and replace them with assertions on the
    #       response_json data sent in the reconciliation loop "simulate_N_poll" methods.

    expect(workspace.user).to eq(user)
    expect(workspace.agent).to eq(agent)
    # noinspection RubyResolve
    expect(workspace.desired_state_updated_at).to eq(Time.current)
    expect(workspace.name).to eq("workspace-#{agent.id}-#{user.id}-#{random_string}")
    namespace_prefix = RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::NAMESPACE_PREFIX
    expect(workspace.namespace).to eq("#{namespace_prefix}-#{agent.id}-#{user.id}-#{random_string}")
    expect(workspace.url).to eq(URI::HTTPS.build({
      host: "60001-#{workspace.name}.#{dns_zone}",
      path: "/",
      query: {
        folder: "#{workspace_root}/#{workspace_project.path}"
      }.to_query
    }).to_s)
    # noinspection RubyResolve
    expect(workspace.devfile).to eq(devfile_yaml)
    actual_processed_devfile = yaml_safe_load_symbolized(workspace.processed_devfile)
    expect(actual_processed_devfile.fetch(:components)).to eq(expected_processed_devfile.fetch(:components))
    expect(actual_processed_devfile).to eq(expected_processed_devfile)

    all_expected_vars = (expected_internal_variables + user_provided_variables).sort_by { |v| v[:key] }
    # NOTE: We convert the actual records into hashes and sort them as a hash rather than ordering in
    #       ActiveRecord, to account for platform- or db-specific sorting differences.
    types = RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES
    all_actual_vars = RemoteDevelopment::WorkspaceVariable.where(workspace: workspace)

    actual_user_provided_vars = all_actual_vars.select(&:user_provided)

    all_actual_vars = all_actual_vars.map { |v| { key: v.key, type: types.invert[v.variable_type], value: v.value } }
    .sort_by { |v| v[:key] }

    # Check that user provided variables had their flag set correctly.
    expect(actual_user_provided_vars.count).to eq(user_provided_variables.count)
    expect(actual_user_provided_vars[0][:key]).to eq(user_provided_variables[0][:key])

    # Check just keys first, to get an easy failure message if a new key has been added
    expect(all_actual_vars.pluck(:key)).to match_array(all_expected_vars.pluck(:key))

    # Then check the full attributes for all vars except gl_token, which must be compared as a regex
    expected_without_regexes = all_expected_vars.reject { |v| v[:key] == "gl_token" }
    actual_without_regexes = all_actual_vars.reject { |v| v[:key] == "gl_token" }
    expect(expected_without_regexes).to match(actual_without_regexes)

    expected_gl_token_value = expected_internal_variables.find { |var| var[:key] == "gl_token" }[:value]
    actual_gl_token_value = all_actual_vars.find { |var| var[:key] == "gl_token" }[:value]
    expect(actual_gl_token_value).to match(expected_gl_token_value)

    workspace
  end

  # rubocop:enable Metrics/AbcSize

  # @param [String] cluster_agent_gid
  def workspace_create_mutation_args(cluster_agent_gid)
    {
      desired_state: states::RUNNING,
      editor: "webide",
      cluster_agent_id: cluster_agent_gid,
      project_id: workspace_project.to_global_id.to_s,
      project_ref: project_ref,
      devfile_path: devfile_path,
      variables: user_provided_variables.each_with_object([]) do |variable, arr|
        arr << variable.merge(type: variable[:type].to_s.upcase)
      end
    }
  end

  # @param [RemoteDevelopment::Workspace] workspace
  def do_start_workspace(workspace)
    do_change_workspace_state(workspace: workspace, desired_state: states::RUNNING)
  end

  # @param [RemoteDevelopment::Workspace] workspace
  def do_stop_workspace(workspace)
    do_change_workspace_state(workspace: workspace, desired_state: states::STOPPED)
  end

  # @param [RemoteDevelopment::Workspace] workspace
  # @param [String] desired_state
  def do_change_workspace_state(workspace:, desired_state:)
    workspace_update_mutation_args = {
      id: global_id_of(workspace),
      desired_state: desired_state
    }

    do_graphql_mutation_post(
      name: :workspace_update,
      input: workspace_update_mutation_args,
      user: user
    )

    # NOTE: Where possible, avoid explicit assertions here and replace them with assertions on the
    #       response_json data sent in the reconciliation loop "simulate_N_poll" methods.

    # noinspection RubyResolve
    expect(workspace.reload.desired_state_updated_at).to eq(Time.current)
  end

  # @param [Symbol] name
  # @param [Hash] input
  # @param [User] user
  def do_graphql_mutation_post(name:, input:, user:)
    mutation = graphql_mutation(name, input)
    post_graphql_mutation(mutation, current_user: user)
    expect_graphql_errors_to_be_empty
    mutation_response = graphql_mutation_response(name)
    expect(mutation_response.fetch("errors")).to eq([])
    mutation_response
  end

  # @param [Hash] params
  # @param [QA::Resource::Clusters::AgentToken] agent_token
  # @return [Hash] response_json with deep symbolized keys
  def do_reconcile_post(params:, agent_token:)
    # Custom logic to perform the reconcile post for a _REQUEST_ spec

    jwt_token = JWT.encode(
      { "iss" => Gitlab::Kas::JWT_ISSUER, 'aud' => Gitlab::Kas::JWT_AUDIENCE },
      Gitlab::Kas.secret,
      "HS256"
    )
    agent_token_headers = {
      "Authorization" => "Bearer #{agent_token.token}",
      Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => jwt_token
    }
    reconcile_url = api("/internal/kubernetes/modules/remote_development/reconcile", personal_access_token: agent_token)

    post reconcile_url, params: params, headers: agent_token_headers, as: :json

    expect(response).to have_gitlab_http_status(:created)
    json_response.deep_symbolize_keys
  end

  shared_examples 'workspace lifecycle' do
    before do
      stub_licensed_features(remote_development: true)
      allow(SecureRandom).to receive(:alphanumeric) { random_string }

      allow(Gitlab::Kas).to receive(:secret).and_return(jwt_secret)

      allow(workspace_project.repository).to receive_message_chain(:blob_at_branch, :data) { devfile_yaml }
    end

    it "successfully exercises the full lifecycle of a workspace", :unlimited_max_formatted_output_length do # rubocop:disable RSpec/NoExpectationExample -- the expectations are in the called methods
      # CREATE THE MAPPING VIA GRAPHQL API, SO WE HAVE PROPER AUTHORIZATION
      do_create_mapping

      # CREATE THE WorkspacesAgentConfig VIA GRAPHQL API
      do_create_workspaces_agent_config

      # CREATE WORKSPACE VIA GRAPHQL API
      workspace = do_create_workspace

      additional_args_for_expected_config_to_apply =
        build_additional_args_for_expected_config_to_apply(
          network_policy_enabled: true,
          dns_zone: dns_zone,
          namespace_path: workspace_project_namespace.full_path,
          project_name: workspace_project_name,
          image_pull_secrets: image_pull_secrets
        )

      # SIMULATE RECONCILE RESPONSE TO AGENTK SENDING NEW WORKSPACE
      simulate_first_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO RUNNING ACTUAL_STATE
      simulate_second_poll(workspace: workspace.reload, agent_token: agent_token)

      # UPDATE WORKSPACE DESIRED_STATE TO STOPPED VIA GRAPHQL API
      do_stop_workspace(workspace)

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO STOPPED DESIRED_STATE
      simulate_third_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPING ACTUAL_STATE
      simulate_fourth_poll(workspace: workspace.reload, agent_token: agent_token)

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPED ACTUAL_STATE
      simulate_fifth_poll(workspace: workspace.reload, agent_token: agent_token)

      # SIMULATE RECONCILE RESPONSE TO AGENTK FOR PARTIAL RECONCILE TO SHOW NO RAILS_INFOS ARE SENT
      simulate_sixth_poll(agent_token: agent_token)

      # SIMULATE RECONCILE RESPONSE TO AGENTK FOR FULL RECONCILE TO SHOW ALL WORKSPACES ARE SENT IN RAILS_INFOS
      simulate_seventh_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        **additional_args_for_expected_config_to_apply
      )

      # UPDATE WORKSPACE DESIRED_STATE BACK TO RUNNING VIA GRAPHQL API
      do_start_workspace(workspace)

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO RUNNING DESIRED_STATE
      simulate_eighth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO RUNNING ACTUAL_STATE
      simulate_ninth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        # TRAVEL FORWARD IN TIME MAX_ACTIVE_HOURS_BEFORE_STOP HOURS
        time_to_travel_after_poll: workspace.workspaces_agent_config.max_active_hours_before_stop.hours
      )

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO STOPPED DESIRED_STATE
      simulate_tenth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPING ACTUAL_STATE
      simulate_eleventh_poll(workspace: workspace.reload, agent_token: agent_token)

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPED ACTUAL_STATE
      simulate_twelfth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        # TRAVEL FORWARD IN TIME MAX_STOPPED_HOURS_BEFORE_TERMINATION HOURS
        time_to_travel_after_poll: workspace.workspaces_agent_config.max_stopped_hours_before_termination.hours
      )

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO TERMINATED DESIRED_STATE
      simulate_thirteenth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO TERMINATING ACTUAL_STATE
      simulate_fourteenth_poll(workspace: workspace.reload, agent_token: agent_token)

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO TERMINATED ACTUAL_STATE
      simulate_fifteenth_poll(workspace: workspace.reload, agent_token: agent_token)
    end
  end

  describe "a happy path workspace lifecycle" do
    # NOTE: Even though this is only called once, we leave it as a shared example, so that we can easily
    #       introduce additional contexts with different behavior for temporary feature flag testing.
    it_behaves_like 'workspace lifecycle'
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
