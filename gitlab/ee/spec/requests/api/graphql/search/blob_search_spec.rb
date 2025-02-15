# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a collection of blobs with multiple matches in a single file', :zoekt,
  feature_category: :global_search do
  include GraphqlHelpers
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :public, :repository, name: 'awesome project', group: group) }
  let(:fields) { all_graphql_fields_for(Types::Search::Blob::BlobSearchType, max_depth: 4) }
  let(:arguments) { { search: 'maintainers', group_id: "gid://gitlab/Group/#{group.id}", chunk_count: 3 } }

  let(:query) { graphql_query_for(:blobSearch, arguments, fields) }

  before do
    stub_licensed_features(zoekt_code_search: true)
  end

  context 'when zoekt is enabled for a group', :zoekt_settings_enabled do
    before do
      zoekt_ensure_project_indexed!(project)
    end

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    describe 'validation for verify_repository_ref!' do
      let(:existing_project_id) { "gid://gitlab/Project/#{project.id}" }
      let(:non_existing_project_id) { "gid://gitlab/Project/#{non_existing_record_id}" }
      let(:default_ref) { project.default_branch }

      using RSpec::Parameterized::TableSyntax
      where(:ref, :p_id, :error) do
        nil               | ref(:existing_project_id)     | false
        ref(:default_ref) | ref(:existing_project_id)     | false
        'dummy'           | ref(:non_existing_project_id) | false
        'dummy'           | ref(:existing_project_id)     | true
        'dummy'           | nil                           | false
      end
      with_them do
        let(:query) { graphql_query_for(:blobSearch, { search: 'test', repository_ref: ref, project_id: p_id }) }
        before do
          post_graphql(query, current_user: current_user)
        end

        it 'raises exception with message Search is only allowed in project default branch when error is true' do
          if error
            expect_graphql_errors_to_include(/Search is only allowed in project default branch/)
          else
            expect_graphql_errors_to_be_empty
          end
        end
      end
    end

    context 'when global search is disabled for blobs' do
      before do
        stub_application_setting(global_search_code_enabled: false)
      end

      context 'when group_id and project_id not passed' do
        let(:query) { graphql_query_for(:blobSearch, { search: 'test' }) }

        it 'raises error Global search is not enabled for this scope' do
          post_graphql(query, current_user: current_user)
          expect_graphql_errors_to_include(/Global search is not enabled for this scope/)
        end
      end
    end

    context 'when search term is invalid' do
      let(:query) do
        graphql_query_for(:blobSearch, { search: '*', group_id: "gid://gitlab/Group/#{group.id}", regex: true })
      end

      it 'raises error parsing regexp: missing argument to repetition operator' do
        post_graphql(query, current_user: current_user)
        expect_graphql_errors_to_include(%r{error parsing regexp: missing argument to repetition operator: `*`})
      end
    end

    it 'returns the correct fields', :aggregate_failures do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(:blobSearch, :fileCount)).to eq(1)
      expect(graphql_data_at(:blobSearch, :matchCount)).to eq(1)
      expect(graphql_data_at(:blobSearch, :perPage)).to eq(20)
      expect(graphql_data_at(:blobSearch, :searchType)).to eq('ZOEKT')
      expect(graphql_data_at(:blobSearch, :searchLevel)).to eq('GROUP')

      # rubocop:disable Layout/LineLength -- Keep it readable
      expected_file = {
        'path' => 'PROCESS.md',
        'fileUrl' => "http://localhost/#{project.full_path}/-/blob/master/PROCESS.md",
        'blameUrl' => "http://localhost/#{project.full_path}/-/blame/master/PROCESS.md",
        'matchCountTotal' => 2,
        'matchCount' => 2,
        'projectPath' => project.full_path,
        'language' => 'Markdown',
        'chunks' => [{
          'matchCountInChunk' => 2,
          'lines' => [
            { 'highlights' => nil, 'lineNumber' => 4, 'text' => '' },
            { 'highlights' => [[116, 126], [188, 198]],
              'lineNumber' => 5, 'text' => "Below we describe the contributing process to GitLab for two reasons. So that contributors know what to expect from maintainers (possible responses, friendly treatment, etc.). And so that maintainers know what to expect from contributors (use the latest version, ensure that the issue is addressed, friendly treatment, etc.).\n" },
            { 'highlights' => nil, 'lineNumber' => 6, 'text' => '' }
          ]
        }]
      }
      # rubocop:enable Layout/LineLength

      expect(graphql_data_at(:blobSearch, :files).first).to eq(expected_file)
    end

    it 'increments the custom search sli apdex' do
      expect(Gitlab::Metrics::GlobalSearchSlis).to receive(:record_apdex).with(
        elapsed: a_kind_of(Numeric),
        search_scope: 'blobs',
        search_type: 'zoekt',
        search_level: 'group'
      )

      post_graphql(query, current_user: current_user)
    end

    context 'when the search results fail' do
      it 'increments the custom search sli error rate with error true' do
        results_double = instance_double(Search::Zoekt::SearchResults, blobs_count: 0,
          failed?: true, error: 'hello error')
        service_double = instance_double(SearchService, level: 'group', scope: 'blobs', search_type: 'zoekt',
          search_results: results_double, search_objects: [])

        allow(SearchService).to receive(:new).and_return(service_double)

        expect(Gitlab::Metrics::GlobalSearchSlis).to receive(:record_error_rate).with(
          error: true,
          search_scope: 'blobs',
          search_type: 'zoekt',
          search_level: 'group'
        )

        post_graphql(query, current_user: current_user)
      end
    end

    context 'when project is archived' do
      before do
        project.update!(archived: true)
      end

      it 'does not return archived projects by default' do
        post_graphql(query, current_user: current_user)
        expect(graphql_data_at(:blobSearch, :fileCount)).to eq(0)
        expect(graphql_data_at(:blobSearch, :files)).to be_empty
      end

      context 'when include_archived is true' do
        let(:arguments) { { search: 'test', group_id: "gid://gitlab/Group/#{group.id}", include_archived: true } }

        it 'returns archived projects' do
          post_graphql(query, current_user: current_user)
          expect(graphql_data_at(:blobSearch, :fileCount)).to be > 0
          expect(graphql_data_at(:blobSearch, :files)).not_to be_empty
        end
      end

      context 'when include_archived is false' do
        let(:arguments) { { search: 'test', group_id: "gid://gitlab/Group/#{group.id}", include_archived: false } }

        it 'does not return archived projects' do
          post_graphql(query, current_user: current_user)
          expect(graphql_data_at(:blobSearch, :fileCount)).to eq(0)
          expect(graphql_data_at(:blobSearch, :files)).to be_empty
        end
      end
    end

    context 'when project is a fork' do
      include ProjectForksHelper

      let_it_be(:group2) { create(:group, :public) }
      let_it_be(:forked_project) { fork_project(project, nil, repository: true, namespace: group2) }
      let(:arguments) { { search: 'test', group_id: "gid://gitlab/Group/#{group2.id}" } }

      before do
        zoekt_ensure_project_indexed!(forked_project)
      end

      it 'does not return forked projects by default' do
        post_graphql(query, current_user: current_user)
        expect(graphql_data_at(:blobSearch, :fileCount)).to eq(0)
        expect(graphql_data_at(:blobSearch, :files)).to be_empty
      end

      context 'when include_forked is true' do
        let(:arguments) { { search: 'test', group_id: "gid://gitlab/Group/#{group2.id}", include_forked: true } }

        it 'returns forked projects' do
          post_graphql(query, current_user: current_user)
          expect(graphql_data_at(:blobSearch, :fileCount)).to be > 0
          expect(graphql_data_at(:blobSearch, :files)).not_to be_empty
        end
      end

      context 'when include_forked is false' do
        let(:arguments) { { search: 'test', group_id: "gid://gitlab/Group/#{group2.id}", include_forked: false } }

        it 'does not return forked projects' do
          post_graphql(query, current_user: current_user)
          expect(graphql_data_at(:blobSearch, :fileCount)).to eq(0)
          expect(graphql_data_at(:blobSearch, :files)).to be_empty
        end
      end
    end

    context 'when search term is abusive' do
      let(:query) { graphql_query_for(:blobSearch, { search: 'not', group_id: "gid://gitlab/Group/#{group.id}" }) }

      it 'returns empty results' do
        post_graphql(query, current_user: current_user)
        expect(graphql_data_at(:blobSearch))
          .to include('fileCount', 'matchCount', 'perPage', 'searchLevel', 'searchType')
        expect(graphql_data_at(:blobSearch, :fileCount)).to be(0)
        expect(graphql_data_at(:blobSearch, :matchCount)).to be(0)
      end
    end
  end

  context 'when zoekt is disabled for a group', :zoekt_settings_enabled do
    it 'raises error Zoekt search is not available for this request' do
      post_graphql(query, current_user: current_user)
      expect_graphql_errors_to_include(/Zoekt search is not available for this request/)
    end
  end
end
