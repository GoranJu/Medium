# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspacesAgentConfigPolicy, feature_category: :workspaces do
  let_it_be(:agent_project_creator, refind: true) { create(:user) }
  let_it_be(:agent_project, refind: true) { create(:project, creator: agent_project_creator) }
  let_it_be(:agent, refind: true) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: agent_project)
  end

  let_it_be(:agent_config) { agent.unversioned_latest_workspaces_agent_config }

  subject(:policy_instance) { described_class.new(user, agent_config) }

  context 'when user can read a cluster agent' do
    let(:user) { agent_project_creator }

    before do
      allow_next_instance_of(described_class) do |policy|
        allow(policy).to receive(:can?).with(:read_cluster_agent, agent).and_return(true)
      end
    end

    it 'allows reading the corrosponding agent config' do
      expect(policy_instance).to be_allowed(:read_workspaces_agent_config)
    end
  end

  context 'when user can not read a cluster agent' do
    let(:user) { create(:admin) }

    before do
      allow_next_instance_of(described_class) do |policy|
        allow(policy).to receive(:can?).with(:read_cluster_agent, agent).and_return(false)
      end
    end

    it 'disallows reading the corrosponding agent config' do
      expect(policy_instance).to be_disallowed(:read_workspaces_agent_config)
    end
  end
end
