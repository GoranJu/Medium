# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'project secrets', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  before do
    provision_project_secrets_manager(secrets_manager)
  end

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  let(:list_query) do
    graphql_query_for(
      'projectSecrets',
      { project_path: project.full_path },
      "nodes { #{all_graphql_fields_for('ProjectSecret', max_depth: 2)} }"
    )
  end

  let(:read_query) do
    graphql_query_for(
      'projectSecret',
      { project_path: project.full_path, name: 'MY_SECRET_1' },
      all_graphql_fields_for('ProjectSecret', max_depth: 2).to_s
    )
  end

  let(:invalid_read_query) do
    graphql_query_for(
      'projectSecret',
      { project_path: project.full_path, name: 'SECRET_DOES_NOT_EXIST' },
      all_graphql_fields_for('ProjectSecret', max_depth: 2).to_s
    )
  end

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let!(:secret_1) do
    create_project_secret(
      project: project,
      name: 'MY_SECRET_1',
      description: 'test description 1',
      branch: 'dev-branch-*',
      environment: 'review/*',
      value: 'test value 1'
    )
  end

  let!(:secret_2) do
    create_project_secret(
      project: project,
      name: 'MY_SECRET_2',
      description: 'test description 2',
      branch: 'master',
      environment: 'production',
      value: 'test value 2'
    )
  end

  context 'when current user is not part of the project' do
    before do
      post_graphql(list_query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is not part of the project and attempts to fetch a secret' do
    before do
      get_graphql(read_query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is not the project owner' do
    before_all do
      project.add_maintainer(current_user)
    end

    before do
      post_graphql(list_query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is not the project owner and attempts to fetch a secret' do
    before_all do
      project.add_maintainer(current_user)
    end

    before do
      get_graphql(read_query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is the project owner' do
    before_all do
      project.add_owner(current_user)
    end

    context 'and the project secrets manager is not active' do
      before do
        secrets_manager.disable!
        post_graphql(list_query, current_user: current_user)
      end

      it 'returns a top-level error' do
        expect(graphql_errors).to be_present
        error_messages = graphql_errors.pluck('message')
        expect(error_messages).to match_array(['Project secrets manager is not active'])
      end
    end

    context 'and the project secrets manager is not active and attempts to fetch a secret' do
      before do
        secrets_manager.disable!
        get_graphql(read_query, current_user: current_user)
      end

      it 'returns a top-level error' do
        expect(graphql_errors).to be_present
        error_messages = graphql_errors.pluck('message')
        expect(error_messages).to match_array(['Project secrets manager is not active'])
      end
    end

    context 'and the project secrets manager is active' do
      before do
        post_graphql(list_query, current_user: current_user)
      end

      it 'returns the list of project secrets' do
        expect(graphql_data_at(:project_secrets, :nodes))
          .to contain_exactly(
            a_graphql_entity_for(
              project: a_graphql_entity_for(project),
              name: secret_1.name,
              description: secret_1.description,
              branch: secret_1.branch,
              environment: secret_1.environment
            ),
            a_graphql_entity_for(
              project: a_graphql_entity_for(project),
              name: secret_2.name,
              description: secret_2.description,
              branch: secret_2.branch,
              environment: secret_2.environment
            )
          )
      end

      context 'and we can fetch secrets' do
        before do
          get_graphql(read_query, current_user: current_user)
        end

        it 'returns a secret' do
          expect(graphql_data_at(:project_secret))
            .to match(
              a_graphql_entity_for(
                project: a_graphql_entity_for(project),
                name: secret_1.name,
                description: secret_1.description,
                branch: secret_1.branch,
                environment: secret_1.environment
              )
            )
        end
      end

      context 'and we error on invalid secret fetches' do
        before do
          get_graphql(invalid_read_query, current_user: current_user)
        end

        it 'returns a top-level error' do
          expect(graphql_errors).to include(a_hash_including('message' => 'Project secret does not exist.'))
        end
      end
    end
  end
end
