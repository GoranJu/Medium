# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::IssueClassProxy, :elastic, feature_category: :global_search do
  subject(:proxy) { described_class.new(Issue, use_separate_indices: true) }

  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:label) { create(:label, project: project) }
  let_it_be_with_reload(:issue) { create(:labeled_issue, title: 'test', project: project, labels: [label]) }
  let(:query) { 'test' }

  let(:options) do
    {
      current_user: user,
      search_level: 'global',
      project_ids: [project.id],
      public_and_internal_projects: false,
      order_by: nil,
      sort: nil
    }
  end

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

    Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
    ensure_elasticsearch_index!
  end

  describe '#issue_aggregations' do
    it 'filters by labels' do
      result = proxy.issue_aggregations('test', options)

      expect(result.first.name).to eq('labels')
      expect(result.first.buckets.first.symbolize_keys).to match(
        key: label.id.to_s,
        count: 1,
        title: label.title,
        type: label.type,
        color: label.color.to_s,
        parent_full_name: label.project.full_name
      )
    end
  end

  describe '#elastic_search' do
    let(:result) { proxy.elastic_search(query, options: options) }

    describe 'search on basis of hidden attribute' do
      context 'when author of the issue is banned', :sidekiq_inline do
        before do
          issue.author.ban
          ensure_elasticsearch_index!
        end

        it 'current_user is an admin user then user can see the issue' do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
          expect(elasticsearch_hit_ids(result)).to include issue.id
        end

        it 'current_user is a non admin user then user can not see the issue' do
          expect(elasticsearch_hit_ids(result)).not_to include issue.id
        end

        it 'current_user is empty then user can not see the issue' do
          options[:current_user] = nil
          result = proxy.elastic_search('test', options: options)
          expect(elasticsearch_hit_ids(result)).not_to include issue.id
        end
      end

      context 'when author of the issue is active' do
        it 'current_user is an admin user then user can see the issue' do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
          expect(elasticsearch_hit_ids(result)).to include issue.id
        end

        it 'current_user is a non admin user then user can see the issue' do
          expect(elasticsearch_hit_ids(result)).to include issue.id
        end

        it 'current_user is empty then user can see the issue' do
          options[:current_user] = nil
          result = proxy.elastic_search('test', options: options)
          expect(elasticsearch_hit_ids(result)).to include issue.id
        end
      end
    end

    describe 'named queries' do
      using RSpec::Parameterized::TableSyntax

      where(:search_level, :projects, :groups) do
        'global'   | []              | []
        'group'    | []              | [ref(:group)]
        'group'    | :any            | [ref(:group)]
        'project'  | :any            | []
        'project'  | [ref(:project)] | []
        'project'  | [ref(:project)] | [ref(:group)]
      end

      with_them do
        let(:project_ids) { projects.eql?(:any) ? projects : projects.map(&:id) }
        let(:group_ids) { groups.map(&:id) }
        let(:options) { base_options }

        let(:base_options) do
          {
            current_user: user,
            search_level: search_level,
            project_ids: project_ids,
            group_ids: group_ids,
            public_and_internal_projects: false,
            order_by: nil,
            sort: nil
          }
        end

        describe 'base query' do
          shared_examples 'a query that uses simple_query_string' do
            it 'includes the correct base query name' do
              result.response

              assert_named_queries('issue:match:search_terms')
            end
          end

          shared_examples 'a query that uses multi_match' do
            it 'includes the correct base query name' do
              result.response

              assert_named_queries('issue:multi_match:or:search_terms', 'issue:multi_match:and:search_terms',
                'issue:multi_match_phrase:search_terms')
            end
          end

          context 'when querying by iid' do
            let(:query) { '#1' }

            it 'includes the correct base query name' do
              result.response

              assert_named_queries('issue:related:iid', 'doc:is_a:issue')
            end
          end

          context 'when search_uses_match_queries feature flag is false' do
            before do
              stub_feature_flags(search_uses_match_queries: false)
            end

            it_behaves_like 'a query that uses simple_query_string'
          end

          context 'when using advanced search syntax' do
            let(:query) { 'test -banner' }

            it_behaves_like 'a query that uses simple_query_string'
          end

          it_behaves_like 'a query that uses multi_match'
        end

        describe 'state filter' do
          it 'does not filter by state in the query' do
            result.response

            assert_named_queries(without: ['filters:state'])
          end

          context 'when state option is provided' do
            let(:options) { base_options.merge(state: 'opened') }

            it 'filters by state in the query' do
              result.response

              assert_named_queries('filters:state')
            end
          end
        end

        describe 'hidden filter' do
          context 'when user can admin all resources' do
            before do
              allow(user).to receive(:can_admin_all_resources?).and_return(true)
            end

            it 'does not filter hidden issues' do
              result.response

              assert_named_queries(without: ['filters:non_hidden'])
            end
          end

          context 'when user cannot admin all resources' do
            before do
              allow(user).to receive(:can_admin_all_resources?).and_return(false)
            end

            it 'filters hidden issues' do
              result.response

              assert_named_queries('filters:not_hidden')
            end
          end
        end

        describe 'label filter' do
          it 'filters the labels in the query' do
            result.response

            assert_named_queries(without: ['filters:label_ids'])
          end

          context 'when label_name option is provided' do
            let(:options) { base_options.merge(label_name: [label.name]) }

            it 'filters the labels in the query' do
              result.response

              assert_named_queries('filters:label_ids')
            end
          end
        end

        describe 'archived filter' do
          context 'when include_archived is set' do
            let(:options) { base_options.merge(include_archived: true) }

            it 'does not have a filter for archived' do
              result.response

              assert_named_queries(without: ['filters:non_archived'])
            end
          end

          context 'when include_archived is not set' do
            let(:options) { base_options }

            it 'applies the filter for archived based on search_level' do
              result.response

              if search_level != 'project'
                assert_named_queries('filters:non_archived')
              else
                assert_named_queries(without: ['filters:non_archived'])
              end
            end
          end
        end
      end
    end
  end
end
