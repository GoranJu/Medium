# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesFromAgentInfosUpdater, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let_it_be(:user) { create(:user) }
  let_it_be(:agent) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }

  let(:desired_state) { RemoteDevelopment::WorkspaceOperations::States::RUNNING }
  let(:actual_state) { RemoteDevelopment::WorkspaceOperations::States::STARTING }

  let(:workspace) do
    create(
      :workspace,
      agent: agent,
      user: user,
      desired_state: desired_state,
      actual_state: actual_state
    )
  end

  let(:workspace_agent_info) do
    RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfo.new(
      name: workspace.name,
      namespace: workspace.namespace,
      actual_state: actual_state,
      deployment_resource_version: "1"
    )
  end

  let(:workspace_agent_infos_by_name) do
    {
      workspace_agent_info.name => workspace_agent_info
    }.symbolize_keys
  end

  let(:context) do
    {
      agent: agent,
      workspace_agent_infos_by_name: workspace_agent_infos_by_name
    }
  end

  subject(:returned_value) do
    described_class.update(context) # rubocop:disable Rails/SaveBang -- this is not an ActiveRecord method
  end

  it "returns persisted workspaces" do
    expect(returned_value).to eq(context.merge(workspaces_from_agent_infos: [workspace]))
  end

  context "when persisted workspace desired_state is RESTART_REQUESTED and actual_state is STOPPED" do
    let(:desired_state) { RemoteDevelopment::WorkspaceOperations::States::RESTART_REQUESTED }
    let(:actual_state) { RemoteDevelopment::WorkspaceOperations::States::STOPPED }

    it "sets persisted workspace desired state to RUNNING" do
      expect(returned_value).to eq(context.merge(workspaces_from_agent_infos: [workspace]))
      expect(workspace.reload.desired_state).to eq(RemoteDevelopment::WorkspaceOperations::States::RUNNING)
    end
  end
end
