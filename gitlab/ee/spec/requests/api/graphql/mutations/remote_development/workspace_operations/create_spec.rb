# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a workspace', feature_category: :workspaces do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:current_user) { user } # NOTE: Some graphql spec helper methods rely on current_user to be set
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:workspace_ancestor_namespace) { create(:group, parent: root_namespace) }
  let_it_be(:workspace_project, reload: true) do
    create(:project, :public, :repository, developers: user, group: workspace_ancestor_namespace)
      .tap do |project|
      project.add_developer(user)
    end
  end

  let_it_be(:agent_project, reload: true) do
    create(:project, :public, :repository, developers: user, group: workspace_ancestor_namespace)
      .tap do |project|
      project.add_developer(user)
    end
  end

  let_it_be(:agent, reload: true) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: agent_project)
  end

  let_it_be(:agent_project_in_different_root_namespace, reload: true) do
    create(:project, :public, :in_group, developers: user)
  end

  let_it_be(:created_workspace, refind: true) do
    create(:workspace, user: user, project: workspace_project)
  end

  let(:desired_state) { RemoteDevelopment::WorkspaceOperations::States::RUNNING }
  let(:devfile_path) { '.devfile.yaml' }

  let(:mutation_expected_varaiables) do
    [
      { key: 'VAR1', value: 'value 1', type: 'ENVIRONMENT', variable_type: 'ENVIRONMENT' },
      { key: 'VAR2', value: 'value 2', type: 'ENVIRONMENT', variable_type: 'ENVIRONMENT' }
    ]
  end

  let(:service_class_expected_variables) do
    [
      { key: 'VAR1', value: 'value 1', type: 'ENVIRONMENT', variable_type: 0 },
      { key: 'VAR2', value: 'value 2', type: 'ENVIRONMENT', variable_type: 0 }
    ]
  end

  let(:all_mutation_args) do
    {
      desired_state: desired_state,
      editor: 'webide',
      cluster_agent_id: agent.to_global_id.to_s,
      project_id: workspace_project.to_global_id.to_s,
      project_ref: 'main',
      devfile_path: devfile_path,
      variables: [
        { key: 'VAR1', value: 'value 1', type: 'ENVIRONMENT' },
        { key: 'VAR2', value: 'value 2', type: 'ENVIRONMENT' }
      ]
    }
  end

  let(:mutation_args) { all_mutation_args }

  let(:mutation) do
    graphql_mutation(:workspace_create, mutation_args)
  end

  let(:expected_service_args) do
    params = all_mutation_args.except(:cluster_agent_id, :project_id)
    params[:variables] = service_class_expected_variables
    params[:agent] = agent
    params[:user] = current_user
    params[:project] = workspace_project

    {
      domain_main_class: ::RemoteDevelopment::WorkspaceOperations::Create::Main,
      domain_main_class_args: {
        user: current_user,
        params: params,
        vscode_extensions_gallery_metadata: { enabled: true },
        vscode_extensions_gallery: { some_gallery_setting: "some-value" }
      },
      auth_ability: :create_workspace,
      auth_subject: workspace_project,
      current_user: current_user
    }
  end

  let(:stub_service_payload) { { workspace: created_workspace } }
  let(:stub_service_response) do
    ServiceResponse.success(payload: stub_service_payload)
  end

  def mutation_response
    graphql_mutation_response(:workspace_create)
  end

  before do
    stub_licensed_features(remote_development: true)

    allow(WebIde::Settings)
      .to receive(:get).with(
        [:vscode_extensions_gallery_metadata, :vscode_extensions_gallery],
        user: current_user,
        vscode_extensions_marketplace_feature_flag_enabled: true
      ).and_return(
        {
          vscode_extensions_gallery_metadata: { enabled: true },
          vscode_extensions_gallery: { some_gallery_setting: "some-value" }
        }
      )

    # reload projects, so any local debugging performed in the tests has the correct state
    workspace_project.reload
    agent_project.reload
  end

  context 'when workspace project and agent project ARE mapped' do
    before_all do
      create(
        :remote_development_namespace_cluster_agent_mapping,
        user: user,
        agent: agent,
        namespace: workspace_ancestor_namespace
      )
    end

    context 'when workspace project and agent project ARE in the same root namespace' do
      shared_examples 'successful create' do
        it 'creates the workspace with expected args' do
          expect(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
            stub_service_response
          end

          post_graphql_mutation(mutation, current_user: user)

          expect_graphql_errors_to_be_empty

          expect(mutation_response.fetch('workspace')['name']).to eq(created_workspace['name'])
        end
      end

      context 'when all required arguments are present' do
        it_behaves_like 'successful create'
      end

      context 'when devfile_path is nil' do
        let(:devfile_path) { nil }

        it_behaves_like 'successful create'
      end

      context 'when devfile_path is not present' do
        let(:devfile_path) { nil }
        let(:mutation_args) { all_mutation_args.except(:devfile_path) }

        it_behaves_like 'successful create'
      end

      context 'when project_ref is not present and devfile_ref is present' do
        let(:mutation_args) { all_mutation_args.except(:project_ref).merge(devfile_ref: 'main') }

        it_behaves_like 'successful create'
      end

      context 'when project_ref and devfile_ref are both present' do
        let(:mutation_args) { all_mutation_args.merge(devfile_ref: 'main1') }

        it_behaves_like 'successful create'
      end

      context "when the agent project no longer exists under the namespace it is mapped to" do
        before do
          agent_project.project_namespace.update!(parent: root_namespace)
        end

        it_behaves_like 'a mutation that returns top-level errors' do
          let(:match_errors) do
            include(/1 mapping\(s\) exist.*but the agent does not reside within the hierarchy/)
          end
        end
      end

      context 'when there are service errors' do
        let(:stub_service_response) { ::ServiceResponse.error(message: 'some error', reason: :bad_request) }

        before do
          allow(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
            stub_service_response
          end
        end

        it_behaves_like 'a mutation that returns errors in the response', errors: ['some error']
      end
    end

    context 'when workspace project and agent project are NOT in the same root namespace' do
      before do
        agent.update!(project: agent_project_in_different_root_namespace)
      end

      it_behaves_like 'a mutation that returns top-level errors' do
        let(:match_errors) do
          include(/1 mapping\(s\) exist.*but the agent does not reside within the hierarchy/)
        end
      end
    end
  end

  context 'when workspace project and agent project are NOT mapped' do
    it_behaves_like 'a mutation that returns top-level errors' do
      let(:match_errors) { include(/provided agent provided must be mapped to an ancestor namespace/) }
    end
  end

  context 'when required arguments are missing' do
    context 'when validates against GraphQL not allow null behaviour' do
      let(:mutation_args) { all_mutation_args.except(:desired_state) }

      it 'returns error about required argument' do
        post_graphql_mutation(mutation, current_user: user)

        expect_graphql_errors_to_include(/provided invalid value for desiredState \(Expected value to not be null\)/)
      end
    end

    context 'when both project_ref and devfile_ref not present' do
      let(:mutation_args) { all_mutation_args.except(:project_ref, :devfile_ref) }

      it 'returns error about required argument' do
        post_graphql_mutation(mutation, current_user: user)

        expect_graphql_errors_to_include(/Either 'project_ref' or deprecated 'devfile_ref' must be provided./)
      end
    end
  end

  context 'when the user cannot create a workspace for the project' do
    let(:current_user) { create(:user) }

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when remote_development feature is unlicensed' do
    before do
      stub_licensed_features(remote_development: false)
    end

    it_behaves_like 'a mutation that returns top-level errors' do
      let(:match_errors) { include(/'remote_development' licensed feature is not available/) }
    end
  end
end
