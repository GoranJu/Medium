# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ClusterAgent'], feature_category: :deployment_management do
  it 'includes the ee specific fields' do
    expect(described_class).to have_graphql_fields(
      :vulnerability_images,
      :workspaces,
      # TODO: clusterAgent.remoteDevelopmentAgentConfig GraphQL is deprecated - remove in 17.10 - https://gitlab.com/gitlab-org/gitlab/-/issues/480769
      :remote_development_agent_config,
      :workspaces_agent_config,
      :is_receptive,
      :url_configurations
    ).at_least
  end

  describe 'vulnerability_images' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:cluster_agent) { create(:cluster_agent, project: project) }
    let_it_be(:vulnerability) do
      create(:vulnerability, :with_cluster_image_scanning_finding,
        agent_id: cluster_agent.id, project: project, report_type: :cluster_image_scanning)
    end

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            clusterAgent(name: "#{cluster_agent.name}") {
              vulnerabilityImages {
                nodes {
                  name
                }
              }
            }
          }
        }
      )
    end

    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    subject(:vulnerability_images) do
      result = GitlabSchema.execute(query, context: { current_user: current_user }).as_json
      result.dig('data', 'project', 'clusterAgent', 'vulnerabilityImages', 'nodes', 0)
    end

    context 'when user is not logged in' do
      let(:current_user) { nil }

      it { is_expected.to be_nil }
    end

    context 'when user is logged in' do
      let(:current_user) { user }

      it 'returns a list of container images reported for vulnerabilities' do
        expect(vulnerability_images).to eq('name' => 'alpine:3.7')
      end
    end
  end

  describe 'workspaces_agent_config' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:cluster_agent) { create(:cluster_agent, project: project) }
    let_it_be(:workspaces_agent_config) do
      create(:workspaces_agent_config, cluster_agent_id: cluster_agent.id, project_id: project.id)
    end

    let_it_be(:remote_development_namespace_cluster_agent_mapping) do
      create(:remote_development_namespace_cluster_agent_mapping, agent: cluster_agent, namespace: group)
    end

    let_it_be(:query) do
      %(
        query {
          namespace(fullPath: "#{group.full_path}") {
            remoteDevelopmentClusterAgents(filter: AVAILABLE) {
              nodes {
                remoteDevelopmentAgentConfig {
                  workspacesPerUserQuota
                }
                workspacesAgentConfig {
                  workspacesPerUserQuota
                }
              }
            }
          }
        }
      )
    end

    before_all do
      project.add_owner(user)
    end

    before do
      stub_licensed_features(remote_development: true)
    end

    # TODO: clusterAgent.remoteDevelopmentAgentConfig GraphQL is deprecated - remove in 17.10 - https://gitlab.com/gitlab-org/gitlab/-/issues/480769
    describe "for remote_development_agent_config" do
      subject(:remote_development_agent_config_result) do
        result = GitlabSchema.execute(query, context: { current_user: current_user }).as_json
        result.dig('data', 'namespace', 'remoteDevelopmentClusterAgents', 'nodes', 0, 'remoteDevelopmentAgentConfig')
      end

      context 'when user is logged in' do
        let(:current_user) { user }
        let(:expected_workspaces_per_user_quota) do
          workspaces_agent_config.workspaces_per_user_quota
        end

        it 'returns associated workspaces agent config' do
          expect(remote_development_agent_config_result).to eq(
            'workspacesPerUserQuota' => expected_workspaces_per_user_quota
          )
        end
      end
    end

    subject(:workspaces_agent_config_result) do
      result = GitlabSchema.execute(query, context: { current_user: current_user }).as_json
      result.dig('data', 'namespace', 'remoteDevelopmentClusterAgents', 'nodes', 0, 'workspacesAgentConfig')
    end

    context 'when user is logged in' do
      let(:current_user) { user }
      let(:expected_workspaces_per_user_quota) do
        workspaces_agent_config.workspaces_per_user_quota
      end

      it 'returns associated workspaces agent config' do
        expect(workspaces_agent_config_result).to eq(
          'workspacesPerUserQuota' => expected_workspaces_per_user_quota
        )
      end
    end
  end
end
