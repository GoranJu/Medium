# frozen_string_literal: true

module RemoteDevelopment
  module IntegrationSpecHelpers
    include ::RemoteDevelopment::WorkspaceOperations::States

    # @param [Boolean] network_policy_enabled
    # @param [String] dns_zone
    # @param [String] namespace_path
    # @param [String] project_name
    def build_additional_args_for_expected_config_to_apply(
      network_policy_enabled:,
      dns_zone:,
      namespace_path:,
      project_name:,
      image_pull_secrets:
    )
      {
        dns_zone: dns_zone,
        namespace_path: namespace_path,
        project_name: project_name,
        include_network_policy: network_policy_enabled,
        image_pull_secrets: image_pull_secrets
      }
    end

    # @param [Array] workspace_agent_infos
    # @param [String] update_type
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    # @param [settingd] Hash
    def simulate_agentk_reconcile_post(workspace_agent_infos:, update_type:, agent_token:, settings:)
      post_params = {
        update_type: update_type,
        workspace_agent_infos: workspace_agent_infos
      }

      # do_reconcile_post contains custom logic for either the request spec or the feature spec.
      response_json = do_reconcile_post(params: post_params, agent_token: agent_token)

      # Assert on settings returned in reconcilation response payload
      expect(response_json.fetch(:settings)).to eq(settings)

      response_json
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    # @param [String] update_type
    # @param [Array] workspace_agent_infos
    # @param [String] expected_desired_state
    # @param [String] expected_actual_state
    # @param [String] expected_resource_version
    # @param [Hash] expected_config_to_apply
    # @param [Integer] expected_rails_infos_count
    # rubocop:disable Metrics/ParameterLists -- This is a test helper, not worth introducing a parameters object, at least for now.
    def simulate_poll(
      workspace:,
      agent_token:,
      update_type:,
      workspace_agent_infos:,
      expected_desired_state:,
      expected_actual_state:,
      expected_resource_version:,
      expected_config_to_apply:,
      expected_rails_infos_count: 1,
      time_to_travel_after_poll: nil
    )
      settings = RemoteDevelopment::Settings.get(
        [
          :partial_reconciliation_interval_seconds,
          :full_reconciliation_interval_seconds
        ]
      )

      # rubocop:enable Metrics/ParameterLists
      response_json = simulate_agentk_reconcile_post(
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type,
        agent_token: agent_token,
        settings: settings
      )

      assert_response(
        response_json,
        workspace: workspace,
        expected_desired_state: expected_desired_state,
        expected_actual_state: expected_actual_state,
        expected_resource_version: expected_resource_version,
        expected_config_to_apply: expected_config_to_apply,
        expected_rails_infos_count: expected_rails_infos_count
      )

      # TRAVEL FORWARD IN TIME TO SIMULATE PASSING TIME BETWEEN RECONCILE REQUESTS
      if time_to_travel_after_poll
        travel(time_to_travel_after_poll)
      else
        reconciliation_interval_seconds = settings.fetch(:"#{update_type}_reconciliation_interval_seconds")

        # Add `travel(...)` based on full or partial reconciliation interval, to control realistic
        # behavior of the `with_desired_state_updated_more_recently_than_last_response_to_agent` scope in
        # `.../workspace_operations/reconcile/persistence/workspaces_to_be_returned_finder.rb`
        travel(reconciliation_interval_seconds)
      end
    end

    # @param [Hash] response_json
    # @param [Workspace] workspace
    # @param [String] expected_desired_state
    # @param [String] expected_actual_state
    # @param [String] expected_resource_version
    # @param [Hash] expected_config_to_apply
    # @param [Integer] expected_rails_infos_count
    def assert_response(
      response_json,
      workspace:,
      expected_desired_state:,
      expected_actual_state:,
      expected_resource_version:,
      expected_config_to_apply:,
      expected_rails_infos_count:
    )
      infos = response_json.fetch(:workspace_rails_infos)
      expect(infos.length).to eq(expected_rails_infos_count)

      return unless expected_rails_infos_count > 0

      workspace.reload

      expect(workspace.responded_to_agent_at).to eq(Time.current)

      info = infos.first

      expect(info.fetch(:name)).to eq(workspace.name)
      expect(info.fetch(:namespace)).to eq(workspace.namespace)
      expect(info.fetch(:desired_state)).to eq(expected_desired_state)
      expect(info.fetch(:actual_state)).to eq(expected_actual_state)
      expect(info.fetch(:deployment_resource_version)).to eq(expected_resource_version)

      config_to_apply = info.fetch(:config_to_apply)
      expect(config_to_apply).to eq(expected_config_to_apply)
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    # @param [Hash] additional_args_for_create_config_to_apply
    def simulate_first_poll(workspace:, agent_token:, **additional_args_for_create_config_to_apply)
      # SIMULATE RECONCILE RESPONSE TO AGENTK SENDING NEW WORKSPACE

      expected_config_to_apply = create_config_to_apply(
        workspace: workspace,
        started: true,
        include_all_resources: true,
        **additional_args_for_create_config_to_apply
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [],
        expected_resource_version: nil,
        expected_desired_state: RUNNING,
        expected_actual_state: CREATION_REQUESTED,
        expected_config_to_apply: expected_config_to_apply
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    def simulate_second_poll(workspace:, agent_token:)
      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO RUNNING ACTUAL_STATE

      resource_version = '1'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: STARTING,
        current_actual_state: RUNNING,
        workspace_exists: true,
        resource_version: resource_version
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: RUNNING,
        expected_actual_state: RUNNING,
        expected_resource_version: resource_version,
        expected_config_to_apply: nil
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    # @param [Hash] additional_args_for_create_config_to_apply
    def simulate_third_poll(
      workspace:,
      agent_token:,
      **additional_args_for_create_config_to_apply
    )
      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO STOPPED DESIRED_STATE

      resource_version = '1'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: STARTING,
        current_actual_state: RUNNING,
        workspace_exists: true,
        resource_version: resource_version
      )

      expected_config_to_apply = create_config_to_apply(
        workspace: workspace,
        started: false,
        **additional_args_for_create_config_to_apply
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: STOPPED,
        expected_actual_state: RUNNING,
        expected_resource_version: resource_version,
        expected_config_to_apply: expected_config_to_apply
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    def simulate_fourth_poll(workspace:, agent_token:)
      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPING ACTUAL_STATE

      resource_version = '2'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: RUNNING,
        current_actual_state: STOPPING,
        workspace_exists: true,
        resource_version: resource_version
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: STOPPED,
        expected_actual_state: STOPPING,
        expected_resource_version: resource_version,
        expected_config_to_apply: nil
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    def simulate_fifth_poll(workspace:, agent_token:)
      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPED ACTUAL_STATE

      resource_version = '3'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: STOPPING,
        current_actual_state: STOPPED,
        workspace_exists: false,
        resource_version: resource_version
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: STOPPED,
        expected_actual_state: STOPPED,
        expected_resource_version: resource_version,
        expected_config_to_apply: nil
      )
    end

    # @param [QA::Resource::Clusters::AgentToken] agent_token
    def simulate_sixth_poll(agent_token:)
      # SIMULATE RECONCILE RESPONSE TO AGENTK FOR PARTIAL RECONCILE TO SHOW NO RAILS_INFOS ARE SENT

      resource_version = '3'
      simulate_poll(
        workspace: nil,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [],
        expected_desired_state: STOPPING,
        expected_actual_state: STOPPED,
        expected_resource_version: resource_version,
        expected_config_to_apply: nil,
        expected_rails_infos_count: 0
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    # @param [Hash] additional_args_for_create_config_to_apply
    def simulate_seventh_poll(
      workspace:,
      agent_token:,
      **additional_args_for_create_config_to_apply
    )
      # SIMULATE RECONCILE RESPONSE TO AGENTK FOR FULL RECONCILE TO SHOW ALL WORKSPACES ARE SENT IN RAILS_INFOS

      resource_version = '3'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: STOPPING,
        current_actual_state: STOPPED,
        workspace_exists: false,
        resource_version: resource_version
      )

      expected_config_to_apply = create_config_to_apply(
        workspace: workspace,
        started: false,
        include_all_resources: true,
        **additional_args_for_create_config_to_apply
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "full",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: STOPPED,
        expected_actual_state: STOPPED,
        expected_resource_version: resource_version,
        expected_config_to_apply: expected_config_to_apply
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    # @param [Hash] additional_args_for_create_config_to_apply
    def simulate_eighth_poll(
      workspace:,
      agent_token:,
      **additional_args_for_create_config_to_apply
    )
      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO RUNNING DESIRED_STATE

      resource_version = '3'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: STOPPING,
        current_actual_state: STOPPED,
        workspace_exists: false,
        resource_version: resource_version
      )

      expected_config_to_apply = create_config_to_apply(
        workspace: workspace,
        started: true,
        **additional_args_for_create_config_to_apply
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: RUNNING,
        expected_actual_state: STOPPED,
        expected_resource_version: resource_version,
        expected_config_to_apply: expected_config_to_apply
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    def simulate_ninth_poll(workspace:, agent_token:, time_to_travel_after_poll:)
      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO RUNNING ACTUAL_STATE

      resource_version = '4'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: STARTING,
        current_actual_state: RUNNING,
        workspace_exists: true,
        resource_version: resource_version
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: RUNNING,
        expected_actual_state: RUNNING,
        expected_resource_version: resource_version,
        expected_config_to_apply: nil,
        time_to_travel_after_poll: time_to_travel_after_poll
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    # @param [Hash] additional_args_for_create_config_to_apply
    def simulate_tenth_poll(
      workspace:,
      agent_token:,
      **additional_args_for_create_config_to_apply
    )
      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO STOPPED DESIRED_STATE

      resource_version = '4'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: STARTING,
        current_actual_state: RUNNING,
        workspace_exists: false,
        resource_version: resource_version
      )

      expected_config_to_apply = create_config_to_apply(
        workspace: workspace,
        started: false,
        **additional_args_for_create_config_to_apply
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: STOPPED,
        expected_actual_state: RUNNING,
        expected_resource_version: resource_version,
        expected_config_to_apply: expected_config_to_apply
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    def simulate_eleventh_poll(workspace:, agent_token:)
      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPING ACTUAL_STATE

      resource_version = '5'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: RUNNING,
        current_actual_state: STOPPING,
        workspace_exists: true,
        resource_version: resource_version
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: STOPPED,
        expected_actual_state: STOPPING,
        expected_resource_version: resource_version,
        expected_config_to_apply: nil
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    def simulate_twelfth_poll(workspace:, agent_token:, time_to_travel_after_poll:)
      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPED ACTUAL_STATE

      resource_version = '6'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: STOPPING,
        current_actual_state: STOPPED,
        workspace_exists: false,
        resource_version: resource_version
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: STOPPED,
        expected_actual_state: STOPPED,
        expected_resource_version: resource_version,
        expected_config_to_apply: nil,
        time_to_travel_after_poll: time_to_travel_after_poll
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    # @param [Hash] additional_args_for_create_config_to_apply
    def simulate_thirteenth_poll(
      workspace:,
      agent_token:,
      **additional_args_for_create_config_to_apply
    )
      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO TERMINATED DESIRED_STATE

      resource_version = '6'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: STOPPING,
        current_actual_state: STOPPED,
        workspace_exists: false,
        resource_version: resource_version
      )

      expected_config_to_apply = create_config_to_apply(
        workspace: workspace,
        started: false,
        **additional_args_for_create_config_to_apply
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: TERMINATED,
        expected_actual_state: STOPPED,
        expected_resource_version: resource_version,
        expected_config_to_apply: expected_config_to_apply
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    def simulate_fourteenth_poll(workspace:, agent_token:)
      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPING ACTUAL_STATE

      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: STOPPED,
        current_actual_state: TERMINATING,
        workspace_exists: true,
        resource_version: nil # NOTE: Resource version returned in agent_infos is null in actual_state=Terminating case
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: TERMINATED,
        expected_actual_state: TERMINATING,
        expected_resource_version: '6',
        expected_config_to_apply: nil
      )
    end

    # @param [Workspace] workspace
    # @param [QA::Resource::Clusters::AgentToken] agent_token
    def simulate_fifteenth_poll(workspace:, agent_token:)
      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO TERMINATED ACTUAL_STATE

      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: TERMINATING,
        current_actual_state: TERMINATED,
        workspace_exists: false,
        resource_version: nil
      )

      simulate_poll(
        workspace: workspace,
        agent_token: agent_token,
        update_type: "partial",
        workspace_agent_infos: [workspace_agent_info],
        expected_desired_state: TERMINATED,
        expected_actual_state: TERMINATED,
        expected_resource_version: '6',
        expected_config_to_apply: nil
      )
    end
  end
end
