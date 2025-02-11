# frozen_string_literal: true

require_relative '../../shared'

RSpec.shared_context 'for a Query.project.clusterAgent.remoteDevelopmentAgentConfig query' do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:agent) { create(:cluster_agent, project: project) }
  let_it_be(:remote_development_agent_config) { create(:workspaces_agent_config, agent: agent) }

  let_it_be(:authorized_user) do
    # create the minimum privileged user that should have the project and namespace
    # permissions to access the remote_development_agent_config.
    create(:user, developer_of: project.namespace)
  end

  let_it_be(:unauthorized_user) do
    # create the maximum privileged user that should NOT have the project and namespace
    # permissions to access the agent.
    create(:user, reporter_of: project.namespace)
  end

  let_it_be(:unauthorized_remote_development_agent_config) { create(:workspaces_agent_config) }

  let(:args) { { full_path: project.full_path } }
  let(:attributes) { { name: agent.name } }
  let(:fields) do
    query_graphql_field(
      :cluster_agent,
      attributes,
      [
        query_graphql_field(
          :remote_development_agent_config,
          all_graphql_fields_for("remote_development_agent_configs".classify, max_depth: 1)
        )
      ]
    )
  end

  let(:query) { graphql_query_for(:project, args, fields) }

  subject(:actual_remote_development_agent_config) do
    graphql_dig_at(graphql_data, :project, :clusterAgent, :remoteDevelopmentAgentConfig)
  end
end

RSpec.shared_examples 'single remoteDevelopmentAgentConfig query' do
  include_context 'in licensed environment'

  context 'when user is authorized' do
    include_context 'with authorized user as current user'

    it_behaves_like 'query is a working graphql query'
    it_behaves_like 'query returns single remote_development_agent_config'

    context 'when the user requests a remote_development_agent_config that they are not authorized for' do
      let(:agent) { unauthorized_remote_development_agent_config.agent }
      let(:project) { agent.project }

      it_behaves_like 'query is a working graphql query'
      it_behaves_like 'query returns blank'
    end
  end

  context 'when user is not authorized' do
    include_context 'with unauthorized user as current user'

    it_behaves_like 'query is a working graphql query'
    it_behaves_like 'query returns blank'
  end

  it_behaves_like 'query in unlicensed environment'
end

RSpec.shared_examples 'query returns single remote_development_agent_config' do
  include GraphqlHelpers

  before do
    post_graphql(query, current_user: current_user)
  end

  it "returns correct object" do
    expect(actual_remote_development_agent_config.fetch('id'))
      .to eq("gid://gitlab/RemoteDevelopment::RemoteDevelopmentAgentConfig/#{remote_development_agent_config.id}")
  end
end
