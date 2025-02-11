# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::SearchResults, :zoekt, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:project_1) { create(:project, :public, :repository) }
  let_it_be(:project_2) { create(:project, :public, :repository) }

  let(:query) { 'hello world' }
  let(:limit_projects) { Project.id_in(project_1.id) }
  let(:node_id) { ::Search::Zoekt::Node.last.id }
  let(:filters) { {} }
  let(:multi_match_enabled) { false }
  let(:results) do
    described_class.new(user, query, limit_projects,
      node_id: node_id, filters: filters,
      multi_match_enabled: multi_match_enabled, modes: { regex: true })
  end

  before do
    zoekt_ensure_project_indexed!(project_1)
    zoekt_ensure_project_indexed!(project_2)
  end

  describe '#objects' do
    using RSpec::Parameterized::TableSyntax
    let(:query) { 'use.*egex' }

    subject(:objects) { results.objects('blobs') }

    it 'finds blobs by regex search' do
      expect(objects.map(&:data).join).to include("def username_regex\n      default_regex")
      expect(results.blobs_count).to eq 5
    end

    it 'sets file_count on the instance equal to the count of files with matches' do
      results.objects('blobs')

      expect(results).to have_attributes(file_count: 2)
    end

    describe 'caching' do
      context 'when multi_match is false' do
        let(:multi_match_enabled) { false }

        it 'instantiates zoekt cache with correct arguments' do
          expect(Search::Zoekt::Cache).to receive(:new).with(
            query,
            current_user: user,
            page: 1,
            per_page: described_class::DEFAULT_PER_PAGE,
            project_ids: [project_1.id],
            max_per_page: described_class::DEFAULT_PER_PAGE * 2,
            search_mode: :regex,
            multi_match: nil
          ).and_call_original

          objects
        end
      end

      context 'when multi_match is true' do
        let(:multi_match_enabled) { true }

        it 'instantiates zoekt cache with correct arguments' do
          expect(Search::Zoekt::Cache).to receive(:new).with(
            query,
            current_user: user,
            page: 1,
            per_page: described_class::DEFAULT_PER_PAGE,
            project_ids: [project_1.id],
            max_per_page: described_class::DEFAULT_PER_PAGE * 2,
            search_mode: :regex,
            multi_match: an_instance_of(Search::Zoekt::MultiMatch)
          ).and_call_original

          objects
        end
      end
    end

    it 'correctly handles pagination' do
      per_page = 2

      blobs_page1 = results.objects('blobs', page: 1, per_page: per_page)
      blobs_page2 = results.objects('blobs', page: 2, per_page: per_page)
      blobs_page3 = results.objects('blobs', page: 3, per_page: per_page)

      expect(blobs_page1.map(&:data).join).to include("def username_regex\n      default_regex")
      expect(blobs_page2.map(&:data).join).to include("regexp group matches\n  (`$1`, `$2`, etc)")
      expect(blobs_page3.map(&:data).join).to include("more readable and you\n  can add some useful comments")
      expect(results.blobs_count).to eq 5
    end

    it 'returns empty result when request is out of page range' do
      blobs_page = results.objects('blobs', page: 256, per_page: 2)

      expect(blobs_page).to be_empty
    end

    context 'when user has access to other projects' do
      let_it_be(:project_3) { create(:project, :repository, :private) }
      let(:limit_projects) { Project.id_in([project_1.id, project_3.id]) }
      let(:query) { 'project_name_regex' }

      before_all do
        zoekt_ensure_project_indexed!(project_3)
        project_3.add_reporter(user)
      end

      it 'respects limit_projects passed in' do
        result_project_ids = objects.map(&:project_id)

        expect(result_project_ids.uniq).to contain_exactly(project_1.id)
        expect(results.blobs_count).to eq 1
      end

      context 'and projects are deleted' do
        it 'removes the blobs of the projects to be deleted' do
          project_3.update!(pending_delete: true)

          result_project_ids = objects.map(&:project_id)
          expect(result_project_ids.uniq).to contain_exactly(project_1.id)
          expect(results.blobs_count).to eq 1
        end
      end
    end

    describe 'regex mode' do
      where(:param_regex_mode, :search_mode_sent_to_client) do
        nil | :exact
        true | :regex
        false | :exact
        'true' | :regex
        'false' | :exact
      end

      with_them do
        it 'calls search on Gitlab::Search::Zoekt::Client with correct parameters' do
          expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
            query,
            num: described_class::ZOEKT_COUNT_LIMIT,
            project_ids: [project_1.id],
            node_id: node_id,
            search_mode: search_mode_sent_to_client
          ).and_call_original

          described_class.new(user, query, limit_projects, node_id: node_id,
            modes: { regex: param_regex_mode }).objects('blobs')
        end

        context 'when a node id is not specified' do
          let(:stubbed_response) do
            instance_double(Gitlab::Search::Zoekt::Response, error_message: 'noop', failure?: true)
          end

          it 'calls search on Gitlab::Search::Zoekt::Client with correct parameters' do
            expect(Gitlab::Search::Zoekt::Client).to receive(:search_multi_node).with(
              query,
              hash_including(use_proxy: true, search_mode: search_mode_sent_to_client)
            ).and_return(stubbed_response)

            described_class.new(user, query, limit_projects, modes: { regex: param_regex_mode }).objects('blobs')
          end

          context 'when feature flag "zoekt_search_proxy" is disabled' do
            before do
              stub_feature_flags(zoekt_search_proxy: false)
            end

            it 'does not use proxy' do
              expect(Gitlab::Search::Zoekt::Client).to receive(:search_multi_node).with(
                query,
                hash_including(use_proxy: false, search_mode: search_mode_sent_to_client)
              ).and_return(stubbed_response)

              described_class.new(user, query, limit_projects, modes: { regex: param_regex_mode }).objects('blobs')
            end
          end
        end
      end

      context 'when modes is not passed' do
        it 'calls search on Gitlab::Search::Zoekt::Client with correct parameters' do
          expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
            query,
            num: described_class::ZOEKT_COUNT_LIMIT,
            project_ids: [project_1.id],
            node_id: node_id,
            search_mode: :exact
          ).and_call_original
          described_class.new(user, query, limit_projects, node_id: node_id).objects('blobs')
        end
      end
    end

    context 'when searching with special characters', :aggregate_failures do
      let_it_be(:examples) do
        {
          'perlMethodCall' => '$my_perl_object->perlMethodCall',
          '"absolute_with_specials.txt"' => '/a/longer/file-path/absolute_with_specials.txt',
          '"components-within-slashes"' => '/file-path/components-within-slashes/',
          'bar\(x\)' => 'Foo.bar(x)',
          'someSingleColonMethodCall' => 'LanguageWithSingleColon:someSingleColonMethodCall',
          'javaLangStaticMethodCall' => 'MyJavaClass::javaLangStaticMethodCall',
          'tokenAfterParentheses' => 'ParenthesesBetweenTokens)tokenAfterParentheses',
          'ruby_call_method_123' => 'RubyClassInvoking.ruby_call_method_123(with_arg)',
          'ruby_method_call' => 'RubyClassInvoking.ruby_method_call(with_arg)',
          '#ambitious-planning' => 'We [plan ambitiously](#ambitious-planning).',
          'ambitious-planning' => 'We [plan ambitiously](#ambitious-planning).',
          'tokenAfterCommaWithNoSpace' => 'WouldHappenInManyLanguages,tokenAfterCommaWithNoSpace',
          'missing_token_around_equals' => 'a.b.c=missing_token_around_equals',
          'and;colons:too\$' => 'and;colons:too$',
          '"differeñt-lønguage.txt"' => 'another/file-path/differeñt-lønguage.txt',
          '"relative-with-specials.txt"' => 'another/file-path/relative-with-specials.txt',
          'ruby_method_123' => 'def self.ruby_method_123(ruby_another_method_arg)',
          'ruby_method_name' => 'def self.ruby_method_name(ruby_method_arg)',
          '"dots.also.neeeeed.testing"' => 'dots.also.neeeeed.testing',
          '.testing' => 'dots.also.neeeeed.testing',
          'dots' => 'dots.also.neeeeed.testing',
          'also.neeeeed' => 'dots.also.neeeeed.testing',
          'neeeeed' => 'dots.also.neeeeed.testing',
          'tests-image' => 'extends: .gitlab-tests-image',
          'gitlab-tests' => 'extends: .gitlab-tests-image',
          'gitlab-tests-image' => 'extends: .gitlab-tests-image',
          'foo/bar' => 'https://s3.amazonaws.com/foo/bar/baz.png',
          'https://test.or.dev.com/repository' => 'https://test.or.dev.com/repository/maven-all',
          'test.or.dev.com/repository/maven-all' => 'https://test.or.dev.com/repository/maven-all',
          'repository/maven-all' => 'https://test.or.dev.com/repository/maven-all',
          'https://test.or.dev.com/repository/maven-all' => 'https://test.or.dev.com/repository/maven-all',
          'bar-baz-conventions' => 'id("foo.bar-baz-conventions")',
          'baz-conventions' => 'id("foo.bar-baz-conventions")',
          'baz' => 'id("foo.bar-baz-conventions")',
          'bikes-3.4' => 'include "bikes-3.4"',
          'sql_log_bin' => 'q = "SET @@session.sql_log_bin=0;"',
          'sql_log_bin=0' => 'q = "SET @@session.sql_log_bin=0;"',
          'v3/delData' => 'uri: "v3/delData"',
          '"us-east-2"' => 'us-east-2'
        }
      end

      before_all do
        examples.values.uniq.each do |file_content|
          file_name = Digest::SHA256.hexdigest(file_content)
          project_1.repository.create_file(user, file_name, file_content, message: 'Some commit message',
            branch_name: 'master')
        end

        zoekt_ensure_project_indexed!(project_1)
      end

      [true, false].each do |multi_match|
        context "when multi_match is #{multi_match}" do
          it 'finds all examples' do
            examples.each do |search_term, file_content|
              file_name = Digest::SHA256.hexdigest(file_content)

              search_results_instance = described_class.new(user, search_term, limit_projects, node_id: node_id,
                modes: { regex: true }, multi_match_enabled: multi_match)

              results = search_results_instance.objects('blobs').map(&:path)
              expect(results).to include(file_name)
            end
          end
        end
      end
    end

    context 'when multi_match_enabled is passed as true' do
      let(:multi_match_enabled) { true }

      it 'returns just one blob of kind Search::FoundMultiLineBlob' do
        expect(results.objects('blobs', per_page: 1)).to contain_exactly(a_kind_of(Search::FoundMultiLineBlob))
      end

      context 'when projects are deleted' do
        let(:limit_projects) { Project.where(id: [project_1.id, project_2.id]) }

        it 'removes the results from the deleted projects' do
          project_2.destroy!
          results_project_paths = results.objects.map(&:project_path).uniq
          expect(results_project_paths).to contain_exactly(project_1.full_path)
        end
      end
    end

    describe 'filtering' do
      include ProjectForksHelper

      let_it_be(:archived_project) { create(:project, :public, :archived, :repository) }
      let!(:forked_project) { fork_project(project_1) }
      let(:all_project_ids) { limit_projects.pluck_primary_key }
      let(:non_archived_project_ids) { all_project_ids - [archived_project.id] }
      let(:non_forked_project_ids) { all_project_ids - [forked_project.id] }
      let(:filters) { {} }

      subject(:search) do
        described_class.new(user, query, limit_projects, node_id: node_id, filters: filters).objects('blobs')
      end

      shared_examples 'a non-filtered search' do
        it 'calls search on Gitlab::Search::Zoekt::Client with all project ids' do
          expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
            query,
            num: described_class::ZOEKT_COUNT_LIMIT,
            project_ids: non_archived_project_ids,
            node_id: node_id,
            search_mode: :exact
          ).and_call_original

          search
        end
      end

      context 'without N+1 queries' do
        it 'does not have N+1 queries for projects' do
          projects = [project_1, project_2]

          collection = ::Project.id_in(projects.map(&:id))

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            described_class.new(user, query, collection, node_id: node_id, filters: filters).objects('blobs')
          end

          projects << create(:project, group: create(:group))
          projects << create(:project, :mirror)

          collection = ::Project.id_in(projects.map(&:id))

          expect do
            described_class.new(user, query, collection, node_id: node_id, filters: filters).objects('blobs')
          end.not_to issue_same_number_of_queries_as(control)
        end
      end

      context 'when no filters are passed' do
        it 'calls search on Gitlab::Search::Zoekt::Client with non archived project ids' do
          expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
            query,
            num: described_class::ZOEKT_COUNT_LIMIT,
            project_ids: non_archived_project_ids,
            node_id: node_id,
            search_mode: :exact
          ).and_call_original

          search
        end
      end

      context 'when there is a public project with a private repository' do
        let(:limit_projects) { ::Project.id_in(public_project_with_private_repo.id) }
        let(:query) { ".*" }
        let(:public_project_with_private_repo) do
          create(:project, :public, :repository, :repository_private, :custom_repo,
            files: { 'foo/a.txt' => 'foo', 'b.txt' => 'bar' })
        end

        before do
          zoekt_ensure_project_indexed!(public_project_with_private_repo)
        end

        it 'does not include results from private repository' do
          expect(Gitlab::Search::Zoekt::Client).not_to receive(:search)

          expect(search).to be_empty
        end

        context 'when there are also permitted repositories in project list' do
          let(:limit_projects) { ::Project.id_in([public_project_with_private_repo.id, project_1.id]) }

          it 'still returns results from permitted repositories' do
            expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
              query,
              num: described_class::ZOEKT_COUNT_LIMIT,
              project_ids: [project_1.id],
              node_id: node_id,
              search_mode: :exact
            ).and_call_original

            expect(search).not_to be_empty
          end
        end
      end

      describe 'archive filters' do
        context 'when include_archived filter is set to true' do
          let(:filters) { { include_archived: true } }

          it_behaves_like 'a non-filtered search'
        end

        context 'when include_archived filter is set to false' do
          let(:filters) { { include_archived: false } }

          it 'calls search on Gitlab::Search::Zoekt::Client with non archived project ids' do
            expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
              query,
              num: described_class::ZOEKT_COUNT_LIMIT,
              project_ids: non_archived_project_ids,
              node_id: node_id,
              search_mode: :exact
            ).and_call_original

            search
          end

          context 'and all projects are archived' do
            let(:limit_projects) { ::Project.archived }

            it 'returns an empty result set' do
              expect(Gitlab::Search::Zoekt::Client).not_to receive(:search)

              expect(search).to be_empty
            end
          end
        end
      end

      describe 'fork filters' do
        context 'when include_forked filter is set to true' do
          let(:filters) { { include_forked: true } }

          it_behaves_like 'a non-filtered search'
        end

        context 'when include_forked filter is set to false' do
          let(:filters) { { include_forked: false } }

          it 'calls search on Gitlab::Search::Zoekt::Client with non archived project ids' do
            expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
              query,
              num: described_class::ZOEKT_COUNT_LIMIT,
              project_ids: non_forked_project_ids,
              node_id: node_id,
              search_mode: :exact
            ).and_call_original

            search
          end

          context 'and all projects are forked' do
            let(:limit_projects) { ::Project.id_in(forked_project.id) }

            it 'returns an empty result set' do
              expect(Gitlab::Search::Zoekt::Client).not_to receive(:search)

              expect(search).to be_empty
            end
          end
        end
      end
    end
  end

  describe '#blobs_count' do
    using RSpec::Parameterized::TableSyntax

    where(:query, :multi_match, :regex_mode, :expected_count) do
      'use.*egex' | true  | false | 0
      'use.*egex' | true  | true  | 5
      'use.*egex' | false | false | 0
      'use.*egex' | false | true  | 5
      'asdfg'     | true  | false | 0
      'asdfg'     | true  | true  | 0
      'asdfg'     | false | false | 0
      'asdfg'     | false | true  | 0
      '# good'    | true  | false | 134
      '# good'    | true  | true  | 564
      '# good'    | false | false | 134
      '# good'    | false | true  | 564
    end

    with_them do
      let(:results) do
        described_class.new(user,
          query,
          limit_projects,
          node_id: node_id,
          multi_match_enabled: multi_match,
          modes: { regex: regex_mode })
      end

      subject(:blobs_count) do
        results.objects('blobs')
        results.blobs_count
      end

      it { is_expected.to eq(expected_count) }

      context 'when error is raised by client' do
        it 'returns zero when error is raised by client' do
          client_error = ::Search::Zoekt::Errors::ClientConnectionError.new('test')
          allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_raise(client_error)

          expect(blobs_count).to eq 0
          expect(results.error).to eq(client_error.message)
        end
      end

      context 'when node backoff occurs' do
        it 'returns zero when a node backoff occurs' do
          client_error = ::Search::Zoekt::Errors::BackoffError.new('test')
          allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_raise(client_error)

          expect(blobs_count).to eq 0
          expect(results.error).to eq(client_error.message)
        end
      end

      it 'limits to the zoekt count limit' do
        stub_const("#{described_class}::ZOEKT_COUNT_LIMIT", 2)

        limited_count = [2, expected_count].min
        expect(blobs_count).to eq(limited_count)
      end
    end
  end

  describe '#failed?' do
    let(:scope) { 'blobs' }

    subject(:results) { described_class.new(user, 'test', limit_projects, node_id: node_id) }

    context 'when no error raised by client' do
      it 'returns false' do
        results.objects(scope)
        expect(results.failed?(scope)).to be false
      end
    end

    context 'when error raised by client' do
      before do
        client_error = ::Search::Zoekt::Errors::ClientConnectionError.new('test')
        allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_raise(client_error)
      end

      it 'returns true' do
        results.objects(scope)
        expect(results.failed?(scope)).to be true
      end
    end
  end

  describe '#error' do
    let(:scope) { 'blobs' }

    subject(:results) { described_class.new(user, 'test', limit_projects, node_id: node_id) }

    context 'when no error raised by client' do
      it 'returns nil' do
        results.objects(scope)
        expect(results.error(scope)).to be_nil
      end
    end

    context 'when error raised by client' do
      before do
        client_error = ::Search::Zoekt::Errors::ClientConnectionError.new('test')
        allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_raise(client_error)
      end

      it 'returns the error message' do
        results.objects(scope)
        expect(results.error(scope)).to eq('test')
      end
    end
  end

  describe '#aggregations' do
    it 'returns an empty array' do
      expect(results.aggregations).to eq([])
    end
  end

  describe '#highlight_map' do
    it 'returns an empty hash' do
      expect(results.highlight_map).to eq({})
    end
  end
end
