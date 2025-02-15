# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['WorkspacesAgentConfig'], feature_category: :workspaces do
  let(:fields) do
    %i[
      id cluster_agent project_id enabled dns_zone network_policy_enabled gitlab_workspaces_proxy_namespace
      workspaces_quota workspaces_per_user_quota default_max_hours_before_termination max_hours_before_termination_limit
      allow_privilege_escalation use_kubernetes_user_namespaces default_runtime_class annotations labels
      default_resources_per_workspace_container max_resources_per_workspace network_policy_egress
      image_pull_secrets created_at updated_at
    ]
  end

  specify { expect(described_class.graphql_name).to eq('WorkspacesAgentConfig') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class).to require_graphql_authorizations(:read_workspaces_agent_config) }

  describe 'workspaces_agent_config' do
    let_it_be(:group) { create(:group) }

    let_it_be(:query) do
      %(
        query {
          namespace(fullPath: "#{group.full_path}") {
            remoteDevelopmentClusterAgents(filter: AVAILABLE) {
              nodes {
                workspacesAgentConfig {
                  defaultMaxHoursBeforeTermination
                }
              }
            }
          }
        }
      )
    end

    subject(:workspaces_agent_config_result) do
      result = GitlabSchema.execute(query, context: { current_user: current_user }).as_json
      result.dig('data', 'namespace', 'remoteDevelopmentClusterAgents', 'nodes', 0, 'workspacesAgentConfig')
    end

    context 'when user is not logged in' do
      let(:current_user) { nil }

      it { is_expected.to be_nil }
    end
  end
end
