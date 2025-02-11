# frozen_string_literal: true

FactoryBot.define do
  # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
  factory :workspace, class: 'RemoteDevelopment::Workspace' do
    # noinspection RailsParamDefResolve -- RubyMine flags this as requiring a hash, but a symbol is a valid option
    association :project, :in_group
    user
    agent factory: [:ee_cluster_agent, :with_existing_workspaces_agent_config]
    personal_access_token

    name { "workspace-#{agent.id}-#{user.id}-#{random_string}" }
    force_include_all_resources { true }

    add_attribute(:namespace) do
      namespace_prefix = RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::NAMESPACE_PREFIX
      "#{namespace_prefix}-#{agent.id}-#{user.id}-#{random_string}"
    end

    desired_state { RemoteDevelopment::WorkspaceOperations::States::STOPPED }
    actual_state { RemoteDevelopment::WorkspaceOperations::States::STOPPED }
    deployment_resource_version { 2 }

    project_ref { 'main' }
    devfile_path { '.devfile.yaml' }

    devfile do
      File.read(Rails.root.join('ee/spec/fixtures/remote_development/example.devfile.yaml').to_s)
    end

    processed_devfile do
      File.read(Rails.root.join('ee/spec/fixtures/remote_development/example.processed-devfile.yaml').to_s)
    end

    transient do
      without_workspace_variables { false }
      random_string { SecureRandom.alphanumeric(6).downcase }
      skip_realistic_after_create_timestamp_updates { false }
      is_after_reconciliation_finish { false }
    end

    # Use this trait if you want to directly control any timestamp fields when invoking the factory.
    trait :without_realistic_after_create_timestamp_updates do
      transient do
        skip_realistic_after_create_timestamp_updates { true }
      end
    end

    # Use this trait if you want to simulate workspace state just after one round of reconciliation where
    # agent has already received config to apply from Rails
    trait :after_initial_reconciliation do
      transient do
        is_after_reconciliation_finish { true }
      end
    end

    after(:build) do |workspace, _|
      user = workspace.user
      workspace.project.add_developer(user)
      workspace.agent.project.add_developer(user)
      workspace.url_prefix ||=
        "#{RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::WORKSPACE_EDITOR_PORT}-#{workspace.name}"
      workspace.url_query_string ||= "folder=dir%2Ffile"
    end

    after(:create) do |workspace, evaluator|
      if evaluator.skip_realistic_after_create_timestamp_updates
        # Set responded_to_agent_at to a non-nil value unless it has already been set
        workspace.update!(responded_to_agent_at: workspace.updated_at) unless workspace.responded_to_agent_at
      elsif evaluator.is_after_reconciliation_finish
        # The most recent activity was reconciliation where info for the workspace was reported to the agent
        # This DOES NOT necessarily mean that the actual and desired states for the workspace are now the same
        # This is because successful convergence of actual & desired states may span more than 1 reconciliation cycle
        workspace.update!(
          desired_state_updated_at: 2.seconds.ago,
          responded_to_agent_at: 1.second.ago
        )
      else
        unless evaluator.without_workspace_variables
          workspace_variables = RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariables.variables(
            name: workspace.name,
            dns_zone: workspace.workspaces_agent_config.dns_zone,
            personal_access_token_value: workspace.personal_access_token.token,
            user_name: workspace.user.name,
            user_email: workspace.user.email,
            workspace_id: workspace.id,
            vscode_extensions_gallery:
              WebIde::Settings::DefaultSettings.default_settings.fetch(:vscode_extensions_gallery).first,
            variables: []
          )

          workspace_variables.each do |workspace_variable|
            workspace.workspace_variables.create!(workspace_variable)
          end
        end

        if workspace.desired_state == workspace.actual_state
          # The most recent activity was a poll that reconciled the desired and actual state.
          desired_state_updated_at = 2.seconds.ago
          responded_to_agent_at = 1.second.ago
        else
          # The most recent activity was a user action which updated the desired state to be different
          # than the actual state.
          desired_state_updated_at = 1.second.ago
          responded_to_agent_at = 2.seconds.ago
        end

        workspace.update!(
          # NOTE: created_at and updated_at are not currently used in any logic, but we set them to be
          #       before desired_state_updated_at or responded_to_agent_at to ensure the record represents
          #       a realistic condition.
          created_at: 3.seconds.ago,
          updated_at: 3.seconds.ago,

          desired_state_updated_at: desired_state_updated_at,
          responded_to_agent_at: responded_to_agent_at
        )
      end
    end

    trait :unprovisioned do
      desired_state { RemoteDevelopment::WorkspaceOperations::States::RUNNING }
      actual_state { RemoteDevelopment::WorkspaceOperations::States::CREATION_REQUESTED }
      responded_to_agent_at { nil }
      deployment_resource_version { nil }
    end

    trait :without_workspace_variables do
      transient do
        without_workspace_variables { true }
      end
    end
  end
end
