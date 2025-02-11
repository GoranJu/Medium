# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Filters, feature_category: :global_search do
  let_it_be_with_reload(:user) { create(:user) }
  let(:query_hash) { { query: { bool: { filter: [], must_not: [], must: [], should: [] } } } }

  shared_examples 'does not modify the query_hash' do
    it 'does not add the filter to query_hash' do
      expect(subject).to eq(query_hash)
    end
  end

  describe '.by_source_branch' do
    subject(:by_source_branch) { described_class.by_source_branch(query_hash: query_hash, options: options) }

    context 'when options[:source_branch] and options[:not_source_branch] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:source_branch] and options[:not_source_branch] are both provided' do
      let(:options) { { source_branch: 'branch-1', not_source_branch: 'branch-2' } }

      it 'adds the source branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { source_branch: { _name: 'filters:source_branch', value: 'branch-1' } } },
              { bool: {
                must_not: {
                  term: { source_branch: { _name: 'filters:not_source_branch', value: 'branch-2' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_source_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_source_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:source_branch] is provided' do
      let(:options) { { source_branch: 'foo-bar-branch' } }

      it 'adds the source branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { source_branch: { _name: 'filters:source_branch', value: 'foo-bar-branch' } } }],
              minimum_should_match: 1 } }
        ]

        expect(by_source_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_source_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:not_source_branch] is provided' do
      let(:options) { { not_source_branch: 'hello-branch' } }

      it 'adds the source branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should:
              [{ bool: {
                must_not: {
                  term: { source_branch: { _name: 'filters:not_source_branch', value: 'hello-branch' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_source_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_source_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_source_branch.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_target_branch' do
    subject(:by_target_branch) { described_class.by_target_branch(query_hash: query_hash, options: options) }

    context 'when options[:target_branch] and options[:not_target_branch] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:target_branch] and options[:not_target_branch] are both provided' do
      let(:options) { { target_branch: 'branch-1', not_target_branch: 'branch-2' } }

      it 'adds the target branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { target_branch: { _name: 'filters:target_branch', value: 'branch-1' } } },
              { bool: {
                must_not: {
                  term: { target_branch: { _name: 'filters:not_target_branch', value: 'branch-2' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_target_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_target_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:target_branch] is provided' do
      let(:options) { { target_branch: 'foo-bar-branch' } }

      it 'adds the target branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { target_branch: { _name: 'filters:target_branch', value: 'foo-bar-branch' } } }],
              minimum_should_match: 1 } }
        ]

        expect(by_target_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_target_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:not_target_branch] is provided' do
      let(:options) { { not_target_branch: 'hello-branch' } }

      it 'adds the target branch filter to query_hash' do
        expected_filter = [
          { bool:
            { should:
              [{ bool: {
                must_not: {
                  term: { target_branch: { _name: 'filters:not_target_branch', value: 'hello-branch' } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_target_branch.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_target_branch.dig(:query, :bool, :must)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :must_not)).to be_empty
        expect(by_target_branch.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_author' do
    let_it_be(:included_user) { user }
    let_it_be(:excluded_user) { create(:user) }

    subject(:by_author) { described_class.by_author(query_hash: query_hash, options: options) }

    context 'when options[:author_username] and options[:not_author_username] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:author_username] and options[:not_author_username] are both provided' do
      let(:options) { { author_username: included_user.username, not_author_username: excluded_user.username } }

      it 'adds the author filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { author_id: { _name: 'filters:author', value: included_user.id } } },
              { bool: {
                must_not: {
                  term: { author_id: { _name: 'filters:not_author', value: excluded_user.id } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_author.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_author.dig(:query, :bool, :must)).to be_empty
        expect(by_author.dig(:query, :bool, :must_not)).to be_empty
        expect(by_author.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:author_username] is provided' do
      let(:options) { { author_username: included_user.username } }

      it 'adds the author filter to query_hash' do
        expected_filter = [
          { bool:
            { should: [{ term: { author_id: { _name: 'filters:author', value: included_user.id } } }],
              minimum_should_match: 1 } }
        ]

        expect(by_author.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_author.dig(:query, :bool, :must)).to be_empty
        expect(by_author.dig(:query, :bool, :must_not)).to be_empty
        expect(by_author.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:not_author_username] is provided' do
      let(:options) { { not_author_username: excluded_user.username } }

      it 'adds the author filter to query_hash' do
        expected_filter = [
          { bool:
            { should:
              [{ bool: {
                must_not: {
                  term: { author_id: { _name: 'filters:not_author', value: excluded_user.id } }
                }
              } }],
              minimum_should_match: 1 } }
        ]

        expect(by_author.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_author.dig(:query, :bool, :must)).to be_empty
        expect(by_author.dig(:query, :bool, :must_not)).to be_empty
        expect(by_author.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_not_hidden' do
    subject(:by_not_hidden) { described_class.by_not_hidden(query_hash: query_hash, options: options) }

    context 'when options[:current_user] is empty' do
      let(:options) { {} }

      it 'adds the hidden filter to query_hash' do
        expected_filter = [{ term: { hidden: { _name: 'filters:not_hidden', value: false } } }]

        expect(by_not_hidden.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_not_hidden.dig(:query, :bool, :must)).to be_empty
        expect(by_not_hidden.dig(:query, :bool, :must_not)).to be_empty
        expect(by_not_hidden.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:current_user] is present' do
      let(:options) { { current_user: user } }

      context 'when user cannot read all resources' do
        it 'adds the hidden filter to query_hash' do
          expected_filter = [{ term: { hidden: { _name: 'filters:not_hidden', value: false } } }]

          expect(by_not_hidden.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_not_hidden.dig(:query, :bool, :must)).to be_empty
          expect(by_not_hidden.dig(:query, :bool, :must_not)).to be_empty
          expect(by_not_hidden.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'when user can read all resources' do
        before do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
        end

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '.by_state' do
    subject(:by_state) { described_class.by_state(query_hash: query_hash, options: options) }

    context 'when options[:state] is empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] is all' do
      let(:options) { { state: 'all' } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] contains an invalid search state' do
      let(:options) { { state: 'invalid' } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] contains a valid search state' do
      let(:options) { { state: 'opened' } }

      it 'adds the state filter to query_hash' do
        expected_filter = [{ match: { state: { _name: 'filters:state', query: 'opened' } } }]

        expect(by_state.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_state.dig(:query, :bool, :must)).to be_empty
        expect(by_state.dig(:query, :bool, :must_not)).to be_empty
        expect(by_state.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_archived' do
    subject(:by_archived) { described_class.by_archived(query_hash: query_hash, options: options) }

    context 'when search_level not provided in options' do
      let(:options) { {} }

      it 'raises an exception' do
        expect { by_archived }.to raise_exception(ArgumentError)
      end
    end

    context 'when options[:include_archived] is empty or false' do
      let(:options) { { include_archived: false, search_level: 'group' } }

      it 'adds the archived filter to query_hash' do
        expected_filter = [
          { bool: { _name: 'filters:non_archived',
                    should: [
                      { bool: { filter: { term: { archived: { value: false } } } } },
                      { bool: { must_not: { exists: { field: 'archived' } } } }
                    ] } }
        ]

        expect(by_archived.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_archived.dig(:query, :bool, :must)).to be_empty
        expect(by_archived.dig(:query, :bool, :must_not)).to be_empty
        expect(by_archived.dig(:query, :bool, :should)).to be_empty
      end

      context 'when options[:search_level] is project' do
        let(:options) { { include_archived: false, search_level: 'project' } }

        it_behaves_like 'does not modify the query_hash'
      end
    end

    context 'when options[:include_archived] is true' do
      let(:options) { { include_archived: true, search_level: 'group' } }

      it_behaves_like 'does not modify the query_hash'

      context 'when options[:search_level] is project' do
        let(:options) { { include_archived: true, search_level: 'project' } }

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '.by_knn' do
    let_it_be(:query_hash) do
      { query: { bool: { filter: [
        { term: { archived: { value: false } } }
      ] } } }
    end

    let_it_be(:embedding) { [0.1, 0.2, 0.3] }

    subject(:by_knn) { described_class.by_knn(query_hash: query_hash, options: options) }

    context 'when embedding is present and vectors are supported' do
      let_it_be(:options) { { embeddings: embedding, vectors_supported: :elasticsearch } }

      it 'merges the knn filter into the query_hash' do
        expect(by_knn).to eq(query_hash.deep_merge(knn: { filter: [{ term: { archived: { value: false } } }] }))
      end
    end

    context 'when embedding is not present' do
      let_it_be(:options) { { embeddings: nil } }

      it 'returns the original query_hash' do
        expect(by_knn).to eq(query_hash)
      end
    end

    context 'when vectors are not supported' do
      let_it_be(:options) { { embeddings: embedding, vectors_supported: false } }

      it 'returns the original query_hash' do
        expect(by_knn).to eq(query_hash)
      end
    end
  end

  describe '.by_label_ids' do
    let_it_be(:label_title) { 'My label' }
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, group: sub_group) }
    # project label must be defined first or the title cannot match
    let_it_be(:project_label) { create(:label, project: project, title: label_title) }
    let_it_be(:project_2) { create(:project, group: group) }
    let_it_be(:project_label_2) { create(:label, project: project_2, title: label_title) }
    let_it_be(:group_label) { create(:group_label, group: group, title: label_title) }
    let_it_be(:another_label) { create(:label, project: project, title: 'Another label') }

    subject(:by_label_ids) { described_class.by_label_ids(query_hash: query_hash, options: options) }

    context 'when options[:label_name] is not provided' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:label_name] is provided' do
      let(:label_name) { [label_title] }
      let(:aggregations) { false }
      let(:count_only) { false }
      let(:group_ids) { nil }
      let(:project_ids) { nil }
      let(:options) do
        {
          label_name: label_name, search_level: search_level, count_only: count_only, aggregations: aggregations,
          group_ids: group_ids, project_ids: project_ids
        }
      end

      context 'when search_level invalid' do
        let(:search_level) { :not_supported }

        it 'raises an exception' do
          expect { by_label_ids }.to raise_exception(ArgumentError)
        end
      end

      context 'when search_level is not provided' do
        let(:options) { { label_name: label_name } }

        it 'raises an exception' do
          expect { by_label_ids }.to raise_exception(ArgumentError)
        end
      end

      context 'for global search' do
        let(:search_level) { :global }

        context 'when multiple label names are provided' do
          let(:label_name) { [label_title, another_label.title] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: contain_exactly(
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                    }
                  },
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(another_label.id)
                    }
                  }
                )
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:group_ids] is provided' do
          let(:group_ids) { [group.id] }

          it 'adds the label_ids filter to query_hash with no group filtering' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end

          context 'when options[:project_ids] is provided' do
            let(:project_ids) { [project.id] }

            it 'adds the label_ids filter to query_hash' do
              expected_filter = [
                bool: {
                  must: [{
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                    }
                  }]
                }
              ]

              expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
            end
          end
        end

        context 'when options[:project_ids] is provided' do
          using RSpec::Parameterized::TableSyntax

          let(:project_ids) { projects == :any ? projects : [projects.id] }

          where(:projects) do
            [:any, ref(:project), ref(:project_2)]
          end

          with_them do
            it 'adds the label_ids filter to query_hash with no project filtering' do
              expected_filter = [
                bool: {
                  must: [{
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                    }
                  }]
                }
              ]

              expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
              expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
            end
          end
        end

        context 'when options[:count_only] is true' do
          let(:count_only) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when options[:aggregation] is true' do
          let(:aggregation) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        it 'adds the label_ids filter to query_hash' do
          expected_filter = [
            bool: {
              must: [{
                terms: {
                  _name: 'filters:label_ids',
                  label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                }
              }]
            }
          ]

          expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'for group search' do
        let(:search_level) { :group }
        let(:group_ids) { [sub_group.id] }
        let(:project_ids) { nil }

        context 'when multiple label names are provided' do
          let(:label_name) { [label_title, another_label.title] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: contain_exactly(
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id)
                    }
                  },
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(another_label.id)
                    }
                  }
                )
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:count_only] is true' do
          let(:count_only) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when options[:aggregation] is true' do
          let(:aggregation) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when top level group is searched' do
          let(:group_ids) { [group.id] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when subgroup is searched' do
          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'for project search' do
        let(:search_level) { :project }
        let(:group_ids) { nil }
        let(:project_ids) { [project.id] }

        context 'when multiple label names are provided' do
          let(:label_name) { [label_title, another_label.title] }

          it 'adds the label_ids filter to query_hash' do
            expected_filter = [
              bool: {
                must: contain_exactly(
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(group_label.id, project_label.id)
                    }
                  },
                  {
                    terms: {
                      _name: 'filters:label_ids',
                      label_ids: contain_exactly(another_label.id)
                    }
                  }
                )
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:group_ids] is provided' do
          let(:group_ids) { [group.id] }

          it 'adds the label_ids filter to query_hash with no group filtering' do
            expected_filter = [
              bool: {
                must: [{
                  terms: {
                    _name: 'filters:label_ids',
                    label_ids: contain_exactly(group_label.id, project_label.id)
                  }
                }]
              }
            ]

            expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
            expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when options[:count_only] is true' do
          let(:count_only) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        context 'when options[:aggregation] is true' do
          let(:aggregation) { true }

          it_behaves_like 'does not modify the query_hash'
        end

        it 'adds the label_ids filter to query_hash' do
          expected_filter = [
            bool: {
              must: [{
                terms: {
                  _name: 'filters:label_ids',
                  label_ids: contain_exactly(group_label.id, project_label.id)
                }
              }]
            }
          ]

          expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
          expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
        end
      end
    end

    context 'when options[:labels] and options[:label_name] are provided' do
      let(:options) { { labels: [project_label.id], label_name: [label_title], search_level: :global } }

      it 'uses label_name option and adds the label_ids filter to query_hash' do
        expected_filter = [
          bool: {
            must: [{
              terms: {
                _name: 'filters:label_ids',
                label_ids: contain_exactly(group_label.id, project_label.id, project_label_2.id)
              }
            }]
          }
        ]

        expect(by_label_ids.dig(:query, :bool, :filter)).to match(expected_filter)
        expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
        expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
        expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
      end

      context 'when options[:count_only] is true' do
        let(:options) { { label_name: [label_title], count_only: true } }

        it_behaves_like 'does not modify the query_hash'
      end

      context 'when options[:aggregation] is true' do
        let(:options) { { label_name: [label_title], aggregation: true } }

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '.by_group_level_authorization' do
    subject(:by_group_level_authorization) do
      described_class.by_group_level_authorization(query_hash: query_hash, options: options)
    end

    context 'when user.can_read_all_resources? is true' do
      let(:base_options) { { current_user: user, search_level: 'global' } }
      let(:options) { base_options }

      before do
        allow(user).to receive(:can_read_all_resources?).and_return(true)
      end

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when user is having permission for the group' do
      let_it_be(:group) { create(:group, :private) }
      let(:base_options) { { current_user: user, search_level: 'group', group_id: group.id, group_ids: [group.id] } }
      let(:options) { base_options }

      before_all do
        group.add_developer(user)
      end

      it 'shows private filter' do
        expected_filter = [
          { bool: { _name: "filters:level:group", minimum_should_match: 1,
                    should: [{ prefix: {
                      traversal_ids: {
                        _name: "filters:level:group:ancestry_filter:descendants",
                        value: group.elastic_namespace_ancestry
                      }
                    } }] } },
          { bool: {
            minimum_should_match: 1,
            should: [
              { bool: { filter: [
                { term: { namespace_visibility_level: {
                  _name: 'filters:namespace_visibility_level:public', value: ::Gitlab::VisibilityLevel::PUBLIC
                } } }
              ] } },
              { bool: { filter: [{ term: { namespace_visibility_level: {
                _name: 'filters:namespace_visibility_level:internal', value: ::Gitlab::VisibilityLevel::INTERNAL
              } } }] } },
              { bool: { filter: [
                { term: {
                  namespace_visibility_level: { _name: 'filters:namespace_visibility_level:private',
                                                value: ::Gitlab::VisibilityLevel::PRIVATE }
                } },
                { terms: { namespace_id: [group.id] } }
              ] } }
            ]
          } }
        ]

        expect(by_group_level_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
        expect(by_group_level_authorization.dig(:query, :bool, :must)).to be_empty
        expect(by_group_level_authorization.dig(:query, :bool, :must_not)).to be_empty
        expect(by_group_level_authorization.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when user is nil' do
      let(:options) { base_options }
      let(:base_options) { { current_user: nil, search_level: 'global' } }

      it 'shows only the public filter' do
        expected_filter = [
          bool: {
            minimum_should_match: 1,
            should: [
              { bool: { filter: [{ term: { namespace_visibility_level: {
                _name: 'filters:namespace_visibility_level:public', value: ::Gitlab::VisibilityLevel::PUBLIC
              } } }] } }
            ]
          }
        ]

        expect(by_group_level_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
        expect(by_group_level_authorization.dig(:query, :bool, :must)).to be_empty
        expect(by_group_level_authorization.dig(:query, :bool, :must_not)).to be_empty
        expect(by_group_level_authorization.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when user is not having permissions to read confidential epics' do
      let(:options) { base_options }
      let(:base_options) { { current_user: user, search_level: 'global' } }

      it 'shows only the public filter' do
        expected_filter = [
          bool: {
            minimum_should_match: 1,
            should: [
              { bool: { filter: [{ term: { namespace_visibility_level: {
                _name: 'filters:namespace_visibility_level:public', value: ::Gitlab::VisibilityLevel::PUBLIC
              } } }] } },
              { bool: { filter: [{ term: { namespace_visibility_level: {
                _name: 'filters:namespace_visibility_level:internal', value: ::Gitlab::VisibilityLevel::INTERNAL
              } } }] } }
            ]
          }
        ]

        expect(by_group_level_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
        expect(by_group_level_authorization.dig(:query, :bool, :must)).to be_empty
        expect(by_group_level_authorization.dig(:query, :bool, :must_not)).to be_empty
        expect(by_group_level_authorization.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_group_level_confidentiality' do
    subject(:by_group_level_confidentiality) do
      described_class.by_group_level_confidentiality(query_hash: query_hash, options: options)
    end

    context 'when user.can_read_all_resources? is true' do
      let(:base_options) { { current_user: user, search_level: 'global' } }
      let(:options) { base_options }

      before do
        allow(user).to receive(:can_read_all_resources?).and_return(true)
      end

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when user is having permission for the group' do
      let_it_be(:group) { create(:group, :private) }
      let(:base_options) { { current_user: user, search_level: 'global' } }
      let(:options) { base_options }

      before_all do
        group.add_developer(user)
      end

      it 'shows the expected filter' do
        expected_filter = [
          bool: { should: [
            { term: { confidential: { value: false, _name: 'filters:non_confidential:groups' } } },
            {
              bool: {
                must: [
                  { term: { confidential: { value: true, _name: "filters:confidential:groups" } } },
                  { terms: { namespace_id: [group.id],
                             _name: "filters:confidential:groups:can_read_confidential_work_items" } }
                ]
              }
            }
          ] }
        ]

        expect(by_group_level_confidentiality.dig(:query, :bool, :filter)).to match(expected_filter)
        expect(by_group_level_confidentiality.dig(:query, :bool, :must)).to be_empty
        expect(by_group_level_confidentiality.dig(:query, :bool, :must_not)).to be_empty
        expect(by_group_level_confidentiality.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when user is nil' do
      let(:options) { base_options }
      let(:base_options) { { current_user: nil, search_level: 'global' } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when user is not having permissions to read confidential epics' do
      let(:options) { base_options }
      let(:base_options) { { current_user: user, search_level: 'global' } }

      it_behaves_like 'does not modify the query_hash'
    end
  end

  describe '.by_project_confidentiality' do
    let_it_be(:authorized_project) { create(:project, developers: [user]) }
    let_it_be(:private_project) { create(:project, :private) }

    subject(:by_project_confidentiality) do
      described_class.by_project_confidentiality(query_hash: query_hash, options: options)
    end

    context 'when options[:confidential] is not passed or not true/false' do
      let(:base_options) { { current_user: user } }
      let(:options) { base_options }

      context 'when user.can_read_all_resources? is true' do
        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it_behaves_like 'does not modify the query_hash'
      end

      context 'when user is authorized for all projects which the query is scoped to' do
        let(:options) { base_options.merge(project_ids: [authorized_project.id]) }

        it_behaves_like 'does not modify the query_hash'
      end

      context 'when user is not authorized for all projects which the query is scoped to' do
        let(:options) { base_options.merge(project_ids: [authorized_project.id, private_project.id]) }

        it 'adds the confidential and non-confidential filters to query_hash' do
          expected_filter = [
            { bool: { should: [
              { term: { confidential: { _name: 'filters:non_confidential', value: false } } },
              { bool: { must: [
                { term: { confidential: { _name: 'filters:confidential', value: true } } },
                {
                  bool: {
                    should: [
                      { term: { author_id: { _name: 'filters:confidential:as_author', value: user.id } } },
                      { term: { assignee_id: { _name: 'filters:confidential:as_assignee', value: user.id } } },
                      { terms: { _name: 'filters:confidential:project:membership:id',
                                 project_id: [authorized_project.id] } }
                    ]
                  }
                }
              ] } }
            ] } }
          ]

          expect(by_project_confidentiality.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_project_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'when options[:current_user] is empty' do
        let(:options) { { project_ids: [authorized_project.id, private_project.id] } }

        it 'adds the non-confidential filters to query_hash' do
          expected_filter = [{ term: { confidential: { _name: 'filters:non_confidential', value: false } } }]

          expect(by_project_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end
    end

    context 'when options[:confidential] is passed' do
      let(:base_options) { { current_user: user, confidential: true } }
      let(:options) { base_options }

      context 'when user.can_read_all_resources? is true' do
        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it 'adds the requested confidential filter to the query hash' do
          expected_filter = [{ term: { confidential: true } }]

          expect(by_project_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'when user is authorized for all projects which the query is scoped to' do
        let(:options) { base_options.merge(project_ids: [authorized_project.id]) }

        it 'adds the requested confidential filter to the query hash' do
          expected_filter = [{ term: { confidential: true } }]

          expect(by_project_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'when user is not authorized for all projects which the query is scoped to' do
        let(:options) { base_options.merge(project_ids: [authorized_project.id, private_project.id]) }

        it 'adds the confidential and non-confidential filters to query_hash' do
          expected_filter = [
            { term: { confidential: true } },
            { bool: { should: [
              { term: { confidential: { _name: 'filters:non_confidential', value: false } } },
              { bool: { must: [
                { term: { confidential: { _name: 'filters:confidential', value: true } } },
                {
                  bool: {
                    should: [
                      { term: { author_id: { _name: 'filters:confidential:as_author', value: user.id } } },
                      { term: { assignee_id: { _name: 'filters:confidential:as_assignee', value: user.id } } },
                      { terms: { _name: 'filters:confidential:project:membership:id',
                                 project_id: [authorized_project.id] } }
                    ]
                  }
                }
              ] } }
            ] } }
          ]

          expect(by_project_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'when options[:current_user] is empty' do
        let(:options) { { project_ids: [authorized_project.id, private_project.id] } }

        it 'adds the non-confidential filters to query_hash' do
          expected_filter = [{ term: { confidential: { _name: 'filters:non_confidential', value: false } } }]

          expect(by_project_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end
    end
  end

  describe '.by_project_authorization' do
    let_it_be_with_reload(:public_group) { create(:group, :public) }
    let_it_be_with_reload(:authorized_project) { create(:project, group: public_group, developers: [user]) }
    let_it_be_with_reload(:private_project) { create(:project, :private, group: public_group) }
    let_it_be_with_reload(:public_project) { create(:project, :public, group: public_group) }
    let(:options) { base_options }
    let(:public_and_internal_projects) { false }
    let(:project_ids) { [] }
    let(:group_ids) { [] }
    let(:features) { 'issues' }
    let(:no_join_project) { false }
    let(:authorization_use_traversal_ids) { true }
    let(:base_options) do
      {
        current_user: user,
        project_ids: project_ids,
        group_ids: group_ids,
        features: features,
        public_and_internal_projects: public_and_internal_projects,
        no_join_project: no_join_project,
        authorization_use_traversal_ids: authorization_use_traversal_ids,
        project_id_field: :project_id,
        project_visibility_level_field: :visibility_level
      }
    end

    subject(:by_project_authorization) do
      described_class.by_project_authorization(query_hash: query_hash, options: options)
    end

    # anonymous users
    context 'when current_user is nil and project_ids is passed empty array' do
      let(:project_ids) { [] }
      let(:user) { nil }

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent: { _name: 'filters:project:parent', parent_type: 'project',
                            query: {
                              bool: {
                                should: [
                                  bool: { filter: [
                                    { terms: { _name: 'filters:project:membership:id', id: [] } },
                                    { terms: { _name: 'filters:project:issues:enabled_or_private',
                                               'issues_access_level' => [::ProjectFeature::ENABLED,
                                                 ::ProjectFeature::PRIVATE] } }
                                  ] }
                                ]
                              }
                            } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    {
                      filter: [
                        { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ]
                    } }
                ]
              }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }
        let(:options) { base_options.merge(features: 'issues') }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool: { filter: [
                    { terms: { _name: 'filters:project:membership:id', id: [] } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    } }
                  ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: { 'issues_access_level' =>
                          { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                            value: ::ProjectFeature::ENABLED } } }
                      ] } }
                ] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    { filter: [
                      { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [
                          ::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE
                        ]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } }
                ]
              } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool:
                      { filter: [
                        { terms: { _name: 'filters:project:membership:id', foo: [] } },
                        { terms: {
                          _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [
                            ::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE
                          ]
                        } }
                      ] } },
                    { bool:
                      { _name: 'filters:project:visibility:20:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                        value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } }
                  ]
                } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when feature access level is set to disabled for the project_ids is passed in array' do
      let(:project_ids) { [public_project.id] }

      before do
        public_project.project_feature.update!(issues_access_level: ::ProjectFeature::DISABLED)
      end

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool: { filter: [
                    { terms: { _name: 'filters:project:membership:id', id: [] } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    } }
                  ] } }
                ] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    {
                      filter: [
                        { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ]
                    } }
                ]
              }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'when features is nil' do
        let(:features) { nil }

        context 'when project_ids is :any' do
          let(:project_ids) { :any }

          it 'returns the expected query' do
            expected_filter = [
              { has_parent:
                { _name: 'filters:project:parent', parent_type: 'project',
                  query: { bool: { should: [
                    { term: { visibility_level: { _name: 'filters:project:any', value: Project::PRIVATE } } }
                  ] } } } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when project_ids is empty' do
          let(:project_ids) { [] }

          it 'returns the expected query' do
            expected_filter = [
              { has_parent:
                { _name: 'filters:project:parent', parent_type: 'project',
                  query: { bool: { should: [
                    { terms: { _name: 'filters:project:membership:id', id: [] } }
                  ] } } } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool: { filter: [
                    { terms: { _name: 'filters:project:membership:id', id: [] } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    } }
                  ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                      value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                        { term: { 'issues_access_level' =>
                          { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                            value: ::ProjectFeature::ENABLED } } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: { 'issues_access_level' =>
                          { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                            value: ::ProjectFeature::ENABLED } } }
                      ] } }
                ] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          context 'when project_visibility_level field is set' do
            let(:options) { base_options.merge(project_visibility_level_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool:
                      { filter: [
                        { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                        { terms: {
                          _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [
                            ::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE
                          ]
                        } }
                      ] } },
                    { bool:
                      { _name: 'filters:project:visibility:10:issues:access_level',
                        filter: [
                          { term: { foo: { _name: 'filters:project:visibility:10',
                                           value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } },
                    { bool:
                      { _name: 'filters:project:visibility:20:issues:access_level',
                        filter: [
                          { term: { foo: { _name: 'filters:project:visibility:20',
                                           value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } }
                  ]
                } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    { filter: [
                      { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [
                          ::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE
                        ]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                      value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } }
                ]
              } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool:
                      { filter: [
                        { terms: { _name: 'filters:project:membership:id', foo: [] } },
                        { terms: {
                          _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [
                            ::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE
                          ]
                        } }
                      ] } },
                    { bool:
                      { _name: 'filters:project:visibility:10:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                        value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } },
                    { bool:
                      { _name: 'filters:project:visibility:20:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                        value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } }
                  ]
                } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when project_ids is passed :any' do
      let(:project_ids) { :any }

      before do
        allow(user).to receive(:can_read_all_resources?).and_return(true)
      end

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [{ bool: { filter: [
                  { term: { visibility_level: { _name: 'filters:project:any',
                                                value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                  { terms: { _name: 'filters:project:issues:enabled_or_private',
                             'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                ] } }] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: { _name: 'filters:project',
                        should: [{ bool: { filter: [
                          { term: { visibility_level: { _name: 'filters:project:any',
                                                        value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                          { terms: {
                            _name: 'filters:project:issues:enabled_or_private',
                            'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                          } }
                        ] } }] } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: { _name: 'filters:project',
                          should: [{ bool: { filter: [
                            { term: { visibility_level: { _name: 'filters:project:any',
                                                          value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                            { terms: {
                              _name: 'filters:project:issues:enabled_or_private',
                              'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                            } }
                          ] } }] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool: { filter: [
                    { term: { visibility_level: { _name: 'filters:project:any',
                                                  value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    } }
                  ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                      value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                        { terms: {
                          _name: 'filters:project:visibility:10:issues:access_level:enabled_or_private',
                          'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { terms: {
                          _name: 'filters:project:visibility:20:issues:access_level:enabled_or_private',
                          'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                        } }
                      ] } }
                ] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: { _name: 'filters:project',
                        should: [
                          { bool:
                            { filter: [
                              { term: { visibility_level: { _name: 'filters:project:any',
                                                            value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                              { terms: { _name: 'filters:project:issues:enabled_or_private',
                                         'issues_access_level' => [::ProjectFeature::ENABLED,
                                           ::ProjectFeature::PRIVATE] } }
                            ] } },
                          { bool:
                            { _name: 'filters:project:visibility:10:issues:access_level',
                              filter: [
                                { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                              value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                                { terms: {
                                  _name: 'filters:project:visibility:10:issues:access_level:enabled_or_private',
                                  'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                                } }
                              ] } },
                          { bool:
                            { _name: 'filters:project:visibility:20:issues:access_level',
                              filter: [
                                { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                              value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                                { terms: {
                                  _name: 'filters:project:visibility:20:issues:access_level:enabled_or_private',
                                  'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                                } }
                              ] } }
                        ] } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: { _name: 'filters:project',
                          should: [
                            { bool:
                              { filter: [
                                { term: { visibility_level: { _name: 'filters:project:any',
                                                              value: ::Gitlab::VisibilityLevel::PRIVATE } } },
                                { terms: { _name: 'filters:project:issues:enabled_or_private',
                                           'issues_access_level' => [::ProjectFeature::ENABLED,
                                             ::ProjectFeature::PRIVATE] } }
                              ] } },
                            { bool:
                              { _name: 'filters:project:visibility:10:issues:access_level',
                                filter: [
                                  { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                                value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                                  { terms: {
                                    _name: 'filters:project:visibility:10:issues:access_level:enabled_or_private',
                                    'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                                  } }
                                ] } },
                            { bool:
                              { _name: 'filters:project:visibility:20:issues:access_level',
                                filter: [
                                  { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                                value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                                  { terms: {
                                    _name: 'filters:project:visibility:20:issues:access_level:enabled_or_private',
                                    'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                                  } }
                                ] } }
                          ] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when project_ids is passed an array' do
      let(:project_ids) { [authorized_project.id, private_project.id, public_project.id] }

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            has_parent: {
              _name: 'filters:project:parent',
              parent_type: 'project',
              query: {
                bool: {
                  should: [
                    { bool: {
                      filter: [
                        { terms: { _name: 'filters:project:membership:id',
                                   id: contain_exactly(authorized_project.id, public_project.id) } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ]
                    } }
                  ]
                }
              }
            }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [

              bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    {
                      filter: [
                        { terms: { _name: 'filters:project:membership:id',
                                   project_id: contain_exactly(authorized_project.id, public_project.id) } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ]
                    } }
                ]
              }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:custom_field) { :foo }
            let(:options) { base_options.merge(project_id_field: custom_field) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool: {
                      filter: [
                        { terms: { _name: 'filters:project:membership:id',
                                   "#{custom_field}": contain_exactly(authorized_project.id, public_project.id) } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ]
                    } }
                  ]
                } }
              ]
              expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool:
                    { filter: [
                      { terms: {
                        _name: 'filters:project:membership:id',
                        id: contain_exactly(authorized_project.id, public_project.id)
                      } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private',
                        'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                      value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } }
                ] } } } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [{ bool: {
              _name: 'filters:project',
              should: [
                { bool:
                  { filter: [
                    { terms: {
                      _name: 'filters:project:membership:id',
                      project_id: contain_exactly(authorized_project.id, public_project.id)
                    } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    } }
                  ] } },
                { bool:
                  { _name: 'filters:project:visibility:10:issues:access_level',
                    filter: [
                      { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                    value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                      { term: {
                        'issues_access_level' =>
                          { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                            value: ::ProjectFeature::ENABLED }
                      } }
                    ] } },
                { bool:
                  { _name: 'filters:project:visibility:20:issues:access_level',
                    filter: [
                      { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                    value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                      { term: {
                        'issues_access_level' =>
                          { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                            value: ::ProjectFeature::ENABLED }
                      } }
                    ] } }
              ]
            } }]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'and project_id_field is provided in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [{ bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    { filter: [
                      { terms: {
                        _name: 'filters:project:membership:id',
                        foo: contain_exactly(authorized_project.id, public_project.id)
                      } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private',
                        'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                      value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                      value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                              value: ::ProjectFeature::ENABLED }
                        } }
                      ] } }
                ]
              } }]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when group_ids is passed an array' do
      let(:group_ids) { [public_group.id] }
      let(:project_ids) { [authorized_project.id, private_project.id, public_project.id] }

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { bool: {
              minimum_should_match: 1,
              should: [{
                prefix: {
                  traversal_ids: {
                    _name: 'filters:namespace:ancestry_filter:descendants',
                    value: "#{public_group.id}-"
                  }
                }
              }]
            } }
          ]
          expected_must_not = [
            { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when traversal_ids_prefix is set in options' do
          let(:options) { base_options.merge(traversal_ids_prefix: :foo) }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                minimum_should_match: 1,
                should: [{
                  prefix: {
                    foo: {
                      _name: 'filters:namespace:ancestry_filter:descendants',
                      value: "#{public_group.id}-"
                    }
                  }
                }]
              } }
            ]
            expected_must_not = [
              { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when authorization_use_traversal_ids is false in options' do
          let(:authorization_use_traversal_ids) { false }

          it 'returns the expected query' do
            expected_filter = [
              has_parent: {
                _name: 'filters:project:parent',
                parent_type: 'project',
                query: {
                  bool: {
                    should: [
                      { bool: {
                        filter: [
                          { terms: { _name: 'filters:project:membership:id',
                                     id: contain_exactly(authorized_project.id, public_project.id) } },
                          { terms: { _name: 'filters:project:issues:enabled_or_private',
                                     'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                        ]
                      } }
                    ]
                  }
                }
              }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                minimum_should_match: 1,
                should: [
                  { prefix: { traversal_ids: {
                    _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-"
                  } } }
                ]
              } }
            ]
            expected_must_not = [
              { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when authorization_use_traversal_ids is false in options' do
            let(:authorization_use_traversal_ids) { false }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool: { filter: [
                      { terms:
                        { _name: 'filters:project:membership:id',
                          project_id: contain_exactly(authorized_project.id, public_project.id) } },
                      { terms:
                        { _name: 'filters:project:issues:enabled_or_private',
                          'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                    ] } }
                  ]
                } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end

          context 'when traversal_ids_prefix is set in options' do
            let(:options) { base_options.merge(traversal_ids_prefix: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  minimum_should_match: 1,
                  should: [{
                    prefix: {
                      foo: {
                        _name: 'filters:namespace:ancestry_filter:descendants',
                        value: "#{public_group.id}-"
                      }
                    }
                  }]
                } }
              ]
              expected_must_not = [
                { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  minimum_should_match: 1,
                  should: [{
                    prefix: {
                      traversal_ids: {
                        _name: 'filters:namespace:ancestry_filter:descendants',
                        value: "#{public_group.id}-"
                      }
                    }
                  }]
                } }
              ]
              expected_must_not = [
                { terms: { _name: 'filters:reject_projects', foo: [private_project.id] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { bool: {
              minimum_should_match: 1,
              should: [{
                prefix: {
                  traversal_ids: {
                    _name: 'filters:namespace:ancestry_filter:descendants',
                    value: "#{public_group.id}-"
                  }
                }
              }]
            } }
          ]
          expected_must_not = [
            { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
          ]

          expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
          expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                minimum_should_match: 1,
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-" } } }
                ]
              } }
            ]
            expected_must_not = [
              { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  minimum_should_match: 1,
                  should: [
                    { prefix:
                      { traversal_ids:
                        { _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-" } } }
                  ]
                } }
              ]
              expected_must_not = [
                { terms: { _name: 'filters:reject_projects', foo: [private_project.id] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when user is not authorized for the group_ids' do
        let_it_be(:internal_group) { create(:group, :internal) }
        let_it_be(:private_project) { create(:project, :private, group: internal_group) }
        let_it_be(:internal_project) { create(:project, :internal, group: internal_group) }

        let(:group_ids) { [internal_group.id] }
        let(:project_ids) { [private_project.id, internal_project.id] }

        context 'when public_and_internal_projects is false' do
          let(:public_and_internal_projects) { false }

          it 'returns the expected query' do
            expected_filter = [
              has_parent: {
                _name: 'filters:project:parent',
                parent_type: 'project',
                query: {
                  bool: {
                    should: [
                      { bool: {
                        filter: [
                          { terms: { _name: 'filters:project:membership:id',
                                     id: [internal_project.id] } },
                          { terms: { _name: 'filters:project:issues:enabled_or_private',
                                     'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                        ]
                      } }
                    ]
                  }
                }
              }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when no_join_project is true' do
            let(:no_join_project) { true }

            it 'returns the expected query' do
              expected_filter = [
                { bool:
                  { _name: 'filters:project',
                    should: [
                      bool: {
                        filter: [
                          { terms: { _name: 'filters:project:membership:id', project_id: [internal_project.id] } },
                          { terms: { _name: 'filters:project:issues:enabled_or_private',
                                     'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                        ]
                      }
                    ] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end

            context 'when project_id_field is set in options' do
              let(:custom_field) { :foo }
              let(:options) { base_options.merge(project_id_field: custom_field) }

              it 'returns the expected query' do
                expected_filter = [
                  { bool:
                    { _name: 'filters:project',
                      should: [
                        bool: {
                          filter: [
                            { terms: { _name: 'filters:project:membership:id',
                                       "#{custom_field}": [internal_project.id] } },
                            { terms: { _name: 'filters:project:issues:enabled_or_private',
                                       'issues_access_level' => [::ProjectFeature::ENABLED,
                                         ::ProjectFeature::PRIVATE] } }
                          ]
                        }
                      ] } }
                ]

                expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
                expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
                expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
                expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
              end
            end
          end
        end

        context 'when public_and_internal_projects is true' do
          let(:public_and_internal_projects) { true }

          it 'returns the expected query' do
            expected_filter = [
              { has_parent:
                { _name: 'filters:project:parent', parent_type: 'project',
                  query: { bool: { should: [
                    { bool:
                      { filter: [
                        { terms: {
                          _name: 'filters:project:membership:id',
                          id: [internal_project.id]
                        } },
                        { terms: {
                          _name: 'filters:project:issues:enabled_or_private',
                          'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                        } }
                      ] } },
                    { bool:
                      { _name: 'filters:project:visibility:10:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                        value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } },
                    { bool:
                      { _name: 'filters:project:visibility:20:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                        value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                value: ::ProjectFeature::ENABLED }
                          } }
                        ] } }
                  ] } } } }
            ]

            expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when no_join_project is true' do
            let(:no_join_project) { true }

            it 'returns the expected query' do
              expected_filter = [
                { bool:
                  { _name: 'filters:project',
                    should: [
                      { bool: { filter: [
                        { terms: { _name: 'filters:project:membership:id', project_id: [internal_project.id] } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                      ] } },
                      { bool:
                        { _name: 'filters:project:visibility:10:issues:access_level',
                          filter: [
                            { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                          value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                            { term: {
                              'issues_access_level' =>
                                { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                                  value: ::ProjectFeature::ENABLED }
                            } }
                          ] } },
                      { bool:
                        { _name: 'filters:project:visibility:20:issues:access_level',
                          filter: [
                            { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                          value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                            { term: {
                              'issues_access_level' =>
                                { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                  value: ::ProjectFeature::ENABLED }
                            } }
                          ] } }
                    ] } }
              ]

              expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
            end

            context 'when project_id_field is set in options' do
              let(:options) { base_options.merge(project_id_field: :foo) }

              it 'returns the expected query' do
                expected_filter = [
                  { bool:
                    { _name: 'filters:project',
                      should: [
                        { bool: { filter: [
                          { terms: { _name: 'filters:project:membership:id', foo: [internal_project.id] } },
                          { terms: { _name: 'filters:project:issues:enabled_or_private',
                                     'issues_access_level' => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE] } }
                        ] } },
                        { bool:
                          { _name: 'filters:project:visibility:10:issues:access_level',
                            filter: [
                              { term: { visibility_level: { _name: 'filters:project:visibility:10',
                                                            value: ::Gitlab::VisibilityLevel::INTERNAL } } },
                              { term: {
                                'issues_access_level' =>
                                  { _name: 'filters:project:visibility:10:issues:access_level:enabled',
                                    value: ::ProjectFeature::ENABLED }
                              } }
                            ] } },
                        { bool:
                          { _name: 'filters:project:visibility:20:issues:access_level',
                            filter: [
                              { term: { visibility_level: { _name: 'filters:project:visibility:20',
                                                            value: ::Gitlab::VisibilityLevel::PUBLIC } } },
                              { term: {
                                'issues_access_level' =>
                                  { _name: 'filters:project:visibility:20:issues:access_level:enabled',
                                    value: ::ProjectFeature::ENABLED }
                              } }
                            ] } }
                      ] } }
                ]

                expect(by_project_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
                expect(by_project_authorization.dig(:query, :bool, :must)).to be_empty
                expect(by_project_authorization.dig(:query, :bool, :must_not)).to be_empty
                expect(by_project_authorization.dig(:query, :bool, :should)).to be_empty
              end
            end
          end
        end
      end
    end
  end

  describe '.by_work_item_type_ids' do
    subject(:by_work_item_type_ids) { described_class.by_work_item_type_ids(query_hash: query_hash, options: options) }

    context 'when options[:work_item_type_ids] and options[:not_work_item_type_ids] are empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:work_item_type_ids] and options[:not_work_item_type_ids] are both provided' do
      let(:options) { { work_item_type_ids: [1], not_work_item_type_ids: [2] } }

      it 'adds the work_item_type_id filter to query_hash' do
        expected_filter = [
          { bool: {
            must: {
              bool: {
                should: [
                  {
                    terms: {
                      _name: 'filters:work_item_type_ids',
                      work_item_type_id: [1]
                    }
                  },
                  {
                    terms: {
                      _name: 'filters:correct_work_item_type_ids',
                      correct_work_item_type_id: [1]
                    }
                  }
                ],
                minimum_should_match: 1
              }
            }
          } },
          { bool: { must_not: {
            bool: {
              should: [
                {
                  terms: {
                    _name: 'filters:not_work_item_type_ids',
                    work_item_type_id: [2]
                  }
                },
                {
                  terms: {
                    _name: 'filters:not_correct_work_item_type_ids',
                    correct_work_item_type_id: [2]
                  }
                }
              ],
              minimum_should_match: 1
            }
          } } }
        ]

        expect(by_work_item_type_ids.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_work_item_type_ids.dig(:query, :bool, :must)).to be_empty
        expect(by_work_item_type_ids.dig(:query, :bool, :must_not)).to be_empty
        expect(by_work_item_type_ids.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:work_item_type_ids] is provided' do
      let(:options) { { work_item_type_ids: [1] } }

      it 'adds the work_item_type_id filter to query_hash' do
        expected_filter = [
          { bool: { must: {
            bool: {
              should: [
                {
                  terms: {
                    _name: 'filters:work_item_type_ids',
                    work_item_type_id: [1]
                  }
                },
                {
                  terms: {
                    _name: 'filters:correct_work_item_type_ids',
                    correct_work_item_type_id: [1]
                  }
                }
              ],
              minimum_should_match: 1
            }
          } } }
        ]

        expect(by_work_item_type_ids.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_work_item_type_ids.dig(:query, :bool, :must)).to be_empty
        expect(by_work_item_type_ids.dig(:query, :bool, :must_not)).to be_empty
        expect(by_work_item_type_ids.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:not_work_item_type_ids] is provided' do
      let(:options) { { not_work_item_type_ids: [1] } }

      it 'adds the work_item_type_id filter to query_hash' do
        expected_filter = [
          { bool: { must_not: {
            bool: {
              should: [
                {
                  terms: {
                    _name: 'filters:not_work_item_type_ids',
                    work_item_type_id: [1]
                  }
                },
                {
                  terms: {
                    _name: 'filters:not_correct_work_item_type_ids',
                    correct_work_item_type_id: [1]
                  }
                }
              ],
              minimum_should_match: 1
            }
          } } }
        ]

        expect(by_work_item_type_ids.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_work_item_type_ids.dig(:query, :bool, :must)).to be_empty
        expect(by_work_item_type_ids.dig(:query, :bool, :must_not)).to be_empty
        expect(by_work_item_type_ids.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '.by_type' do
    let(:options) { { doc_type: 'my_type' } }

    subject(:by_type) { described_class.by_type(query_hash: query_hash, options: options) }

    it 'adds the doc type filter to the query_hash' do
      expected_filter = [{ term: { type: { _name: 'filters:doc:is_a:my_type', value: 'my_type' } } }]

      expect(by_type.dig(:query, :bool, :filter)).to eq(expected_filter)
      expect(by_type.dig(:query, :bool, :must)).to be_empty
      expect(by_type.dig(:query, :bool, :must_not)).to be_empty
      expect(by_type.dig(:query, :bool, :should)).to be_empty
    end

    context 'when doc_type not provided in options' do
      let(:options) { {} }

      it 'raises an exception' do
        expect { by_type }.to raise_exception(ArgumentError)
      end
    end
  end

  describe '.by_search_level_and_membership' do
    using RSpec::Parameterized::TableSyntax

    subject(:by_search_level_and_membership) do
      described_class.by_search_level_and_membership(query_hash: query_hash, options: options)
    end

    let_it_be(:grp_public) { create(:group, :public) }
    let_it_be(:grp_public_prj_public) { create(:project, :public, group: grp_public) }
    let_it_be(:grp_public_prj_internal) { create(:project, :internal, group: grp_public) }

    let_it_be(:sub_grp_internal) { create(:group, :internal, parent: grp_public) }
    let_it_be(:sub_grp_internal_prj_internal) { create(:project, :internal, group: sub_grp_internal) }
    let_it_be(:sub_grp_internal_prj_private) { create(:project, :private, group: sub_grp_internal) }

    let_it_be(:sub_grp_private) { create(:group, :private, parent: grp_public) }
    let_it_be(:sub_grp_private_prj_private) { create(:project, :private, group: sub_grp_private) }

    let_it_be(:grp_private) { create(:group, :private) }
    let_it_be(:grp_private_prj_private) { create(:project, :private, group: grp_private) }
    let_it_be(:grp_shared) { create(:group, :private) }
    let_it_be(:grp_shared_prj_private_link) do
      create(:project_group_link, :reporter, project: grp_private_prj_private, group: grp_shared)
    end

    let_it_be(:grp_private_2) { create(:group, :private) }
    let_it_be(:sub_grp_private_2) { create(:group, :private, parent: grp_private_2) }
    let_it_be(:sub_grp_private_2_prj_private) { create(:project, :private, group: sub_grp_private_2) }

    let(:auth_projects) { [] }
    let(:auth_groups) { [] }

    before do
      stub_licensed_features(custom_roles: true)
    end

    shared_examples 'a query filtered by search level and membership' do
      it 'returns the expected query' do
        expect(by_search_level_and_membership.dig(:query, :bool, :filter))
          .to match(expected_access_filter)
        expect(by_search_level_and_membership.dig(:query, :bool, :must)).to be_empty
        expect(by_search_level_and_membership.dig(:query, :bool, :must_not)).to be_empty
        expect(by_search_level_and_membership.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when invalid search_level is provided' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: :foobar,
          features: :repository
        }
      end

      it 'raises an error' do
        expect { by_search_level_and_membership }.to raise_error(ArgumentError)
      end
    end

    context 'for global search' do
      let(:search_level) { :global }
      let(:options) do
        {
          current_user: user,
          project_ids: [],
          group_ids: [],
          search_level: search_level,
          features: :repository
        }
      end

      context 'when user has no access' do
        let_it_be(:user) { create(:user) }
        let(:expected_access_filter) { [user_public_access_filter] }

        it_behaves_like 'a query filtered by search level and membership'
      end

      context 'when user has access' do
        let_it_be(:read_code_role) { create(:member_role, :guest, :read_code, namespace: grp_private_2) }
        let_it_be(:admin_runners_role) do
          create(:member_role, :guest, :admin_runners, namespace: grp_private, read_code: false)
        end

        let(:auth_projects) { [grp_private_prj_private, sub_grp_private_prj_private] }
        let(:auth_groups) { [grp_private_2, grp_shared, sub_grp_internal] }
        let(:expected_access_filter) do
          [
            { bool:
              { _name: 'filters:permissions:global',
                should: [
                  public_and_internal_and_enabled_filter,
                  global_member_access_filter
                ],
                minimum_should_match: 1 } }
          ]
        end

        before_all do
          sub_grp_internal.add_developer(user)
          sub_grp_private_prj_private.add_developer(user)
          grp_shared.add_developer(user)

          create(:group_member, :guest, member_role: read_code_role, user: user, source: grp_private_2)
          create(:group_member, :guest, member_role: admin_runners_role, user: user, source: grp_private)
        end

        it_behaves_like 'a query filtered by search level and membership'
      end

      context 'when user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }
        let(:expected_access_filter) { [admin_public_access_filter] }

        it_behaves_like 'a query filtered by search level and membership'
      end

      context 'when user is anonymous' do
        let(:user) { nil }
        let(:expected_access_filter) { [no_user_public_access_filter] }

        it_behaves_like 'a query filtered by search level and membership'
      end
    end

    context 'for group search' do
      let(:search_level) { :group }
      let(:options) do
        {
          current_user: user,
          project_ids: [],
          group_ids: groups.map(&:id),
          search_level: search_level,
          features: :repository,
          project_visibility_level_field: :visibility_level
        }
      end

      context 'when user has no access' do
        let_it_be(:user) { create(:user) }
        let(:expected_access_filter) { [group_filter, user_public_access_filter] }

        where(:groups) do
          [
            [[ref(:grp_public)]],
            [[ref(:sub_grp_internal)]],
            [[ref(:sub_grp_private)]],
            [[ref(:sub_grp_private), ref(:sub_grp_internal)]],
            [[ref(:sub_grp_internal), ref(:grp_private)]],
            [[ref(:sub_grp_private), ref(:grp_private)]],
            [[ref(:grp_private)]],
            [[ref(:grp_private_2)]]
          ]
        end

        with_them do
          it_behaves_like 'a query filtered by search level and membership'
        end
      end

      context 'when user has access' do
        let_it_be(:read_code_role) { create(:member_role, :guest, :read_code, namespace: grp_private_2) }
        let_it_be(:admin_runners_role) do
          create(:member_role, :guest, :admin_runners, namespace: grp_private, read_code: false)
        end

        let(:expected_access_filter) do
          [group_filter].tap do |filters|
            filters << if auth_projects.any? || auth_groups.any?
                         member_with_access_filter
                       else
                         user_public_access_filter
                       end
          end
        end

        before_all do
          sub_grp_internal.add_developer(user)
          sub_grp_private_prj_private.add_developer(user)
          grp_shared.add_developer(user)

          create(:group_member, :guest, member_role: read_code_role, user: user, source: grp_private_2)
          create(:group_member, :guest, member_role: admin_runners_role, user: user, source: grp_private)
        end

        # rubocop:disable Layout/LineLength -- splitting the table syntax affects readability
        where(:groups, :auth_projects, :auth_groups) do
          [ref(:grp_public)] | [ref(:sub_grp_private_prj_private)] | [ref(:sub_grp_internal)]
          [ref(:sub_grp_private)] | [ref(:sub_grp_private_prj_private)] | []
          [ref(:sub_grp_internal)] | [] | [ref(:sub_grp_internal)]
          [ref(:sub_grp_private), ref(:sub_grp_internal)] | [ref(:sub_grp_private_prj_private)] | [ref(:sub_grp_internal)]
          [ref(:sub_grp_internal), ref(:grp_private)] | [ref(:grp_private_prj_private)] | [ref(:sub_grp_internal)]
          [ref(:sub_grp_private), ref(:grp_private)] | [ref(:sub_grp_private_prj_private), ref(:grp_private_prj_private)] | []
          [ref(:grp_private)] | [ref(:grp_private_prj_private)] | []
          [ref(:grp_private_2)] | [] | [ref(:grp_private_2)]
          [ref(:sub_grp_private_2)] | [] | [ref(:sub_grp_private_2)]
        end
        # rubocop:enable Layout/LineLength

        with_them do
          it_behaves_like 'a query filtered by search level and membership'
        end
      end

      context 'when user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }
        let(:expected_access_filter) { [group_filter, admin_public_access_filter] }

        where(:groups) do
          [
            [[ref(:grp_public)]],
            [[ref(:sub_grp_internal)]],
            [[ref(:sub_grp_private)]],
            [[ref(:sub_grp_private), ref(:sub_grp_internal)]],
            [[ref(:sub_grp_internal), ref(:grp_private)]],
            [[ref(:sub_grp_private), ref(:grp_private)]],
            [[ref(:grp_private)]],
            [[ref(:grp_private_2)]]
          ]
        end

        with_them do
          it_behaves_like 'a query filtered by search level and membership'
        end
      end

      context 'when user is anonymous' do
        let(:user) { nil }
        let(:expected_access_filter) { [group_filter, no_user_public_access_filter] }

        where(:groups) do
          [
            [[ref(:grp_public)]],
            [[ref(:sub_grp_internal)]],
            [[ref(:sub_grp_private)]],
            [[ref(:sub_grp_private), ref(:sub_grp_internal)]],
            [[ref(:sub_grp_internal), ref(:grp_private)]],
            [[ref(:sub_grp_private), ref(:grp_private)]],
            [[ref(:grp_private)]],
            [[ref(:grp_private_2)]]
          ]
        end

        with_them do
          it_behaves_like 'a query filtered by search level and membership'
        end
      end
    end

    context 'for project search' do
      let(:search_level) { :project }
      let(:options) do
        {
          current_user: user,
          project_ids: projects.map(&:id),
          group_ids: groups.map(&:id),
          search_level: search_level,
          features: :repository,
          project_visibility_level_field: :visibility_level
        }
      end

      context 'when user has no access' do
        let_it_be(:user) { create(:user) }
        let(:expected_access_filter) { [project_filter, user_public_access_filter] }

        where(:groups, :projects) do
          [ref(:grp_public)] | [ref(:grp_public_prj_public)]
          [ref(:grp_public)] | [ref(:grp_public_prj_internal)]
          [ref(:sub_grp_private)] | [ref(:sub_grp_private_prj_private)]
          [ref(:sub_grp_internal)] | [ref(:sub_grp_internal_prj_internal)]
          [ref(:grp_private)] | [ref(:grp_private_prj_private)]
          [ref(:sub_grp_private_2)] | [ref(:sub_grp_private_2_prj_private)]
          [] | [ref(:grp_public_prj_internal)]
          [] | [ref(:grp_public_prj_internal), ref(:sub_grp_private_prj_private)]
          [] | [ref(:sub_grp_private_prj_private)]
          [] | [ref(:sub_grp_private_prj_private), ref(:sub_grp_private_2_prj_private)]
          [] | [ref(:sub_grp_internal_prj_internal)]
          [] | [ref(:grp_private_prj_private)]
          [] | [ref(:sub_grp_private_2_prj_private)]
        end

        with_them do
          it_behaves_like 'a query filtered by search level and membership'
        end
      end

      context 'when user has access' do
        let_it_be(:read_code_role) { create(:member_role, :guest, :read_code, namespace: grp_private_2) }
        let_it_be(:admin_runners_role) do
          create(:member_role, :guest, :admin_runners, namespace: grp_private, read_code: false)
        end

        let(:expected_access_filter) do
          [project_filter].tap do |filters|
            filters << if auth_projects.any? || auth_groups.any?
                         member_with_access_filter
                       else
                         user_public_access_filter
                       end
          end
        end

        before_all do
          sub_grp_internal.add_developer(user)
          sub_grp_private_prj_private.add_developer(user)
          grp_shared.add_developer(user)

          create(:group_member, :guest, member_role: read_code_role, user: user, source: grp_private_2)
          create(:group_member, :guest, member_role: admin_runners_role, user: user, source: grp_private)
        end

        where(:groups, :projects, :auth_projects, :auth_groups) do
          [ref(:grp_public)] | [ref(:grp_public_prj_public)] | [] | []
          [ref(:grp_public)] | [ref(:grp_public_prj_internal)] | [] | []
          [ref(:sub_grp_private)] | [ref(:sub_grp_private_prj_private)] | [ref(:sub_grp_private_prj_private)] | []
          [ref(:sub_grp_internal)] | [ref(:sub_grp_internal_prj_internal)] | [] | [ref(:sub_grp_internal)]
          [ref(:sub_grp_internal)] | [ref(:sub_grp_internal_prj_private)] | [] | [ref(:sub_grp_internal)]
          [ref(:grp_private)] | [ref(:grp_private_prj_private)] | [ref(:grp_private_prj_private)] | []
          [ref(:sub_grp_private_2)] | [ref(:sub_grp_private_2_prj_private)] | [] | [ref(:sub_grp_private_2)]
          [] | [ref(:grp_public_prj_internal)] | [] | []
          [] | [ref(:sub_grp_private_prj_private)] | [ref(:sub_grp_private_prj_private)] | []
          [] | [ref(:sub_grp_internal_prj_internal)] | [] | [ref(:sub_grp_internal)]
          [] | [ref(:sub_grp_internal_prj_private)] | [] | [ref(:sub_grp_internal)]
          [] | [ref(:grp_private_prj_private)] | [ref(:grp_private_prj_private)] | []
          [] | [ref(:sub_grp_private_2_prj_private)] | [] | [ref(:sub_grp_private_2)]
        end

        with_them do
          it_behaves_like 'a query filtered by search level and membership'
        end
      end

      context 'when user is an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }
        let(:expected_access_filter) { [project_filter, admin_public_access_filter] }

        where(:groups, :projects) do
          [ref(:grp_public)] | [ref(:grp_public_prj_public)]
          [ref(:grp_public)] | [ref(:grp_public_prj_internal)]
          [ref(:sub_grp_private)] | [ref(:sub_grp_private_prj_private)]
          [ref(:sub_grp_internal)] | [ref(:sub_grp_internal_prj_internal)]
          [ref(:sub_grp_internal)] | [ref(:sub_grp_internal_prj_private)]
          [ref(:grp_private)] | [ref(:grp_private_prj_private)]
          [ref(:sub_grp_private_2)] | [ref(:sub_grp_private_2_prj_private)]
          [] | [ref(:grp_public_prj_internal)]
          [] | [ref(:sub_grp_private_prj_private)]
          [] | [ref(:sub_grp_internal_prj_internal)]
          [] | [ref(:sub_grp_internal_prj_private)]
          [] | [ref(:grp_private_prj_private)]
          [] | [ref(:sub_grp_private_2_prj_private)]
        end

        with_them do
          it_behaves_like 'a query filtered by search level and membership'
        end
      end

      context 'when user is anonymous' do
        let(:user) { nil }
        let(:expected_access_filter) { [project_filter, no_user_public_access_filter] }

        where(:groups, :projects) do
          [ref(:grp_public)] | [ref(:grp_public_prj_public)]
          [ref(:grp_public)] | [ref(:grp_public_prj_internal)]
          [ref(:sub_grp_private)] | [ref(:sub_grp_private_prj_private)]
          [ref(:sub_grp_internal)] | [ref(:sub_grp_internal_prj_internal)]
          [ref(:sub_grp_internal)] | [ref(:sub_grp_internal_prj_private)]
          [ref(:grp_private)] | [ref(:grp_private_prj_private)]
          [ref(:sub_grp_private_2)] | [ref(:sub_grp_private_2_prj_private)]
          [] | [ref(:grp_public_prj_internal)]
          [] | [ref(:sub_grp_private_prj_private)]
          [] | [ref(:sub_grp_internal_prj_internal)]
          [] | [ref(:sub_grp_internal_prj_private)]
          [] | [ref(:grp_private_prj_private)]
          [] | [ref(:sub_grp_private_2_prj_private)]
        end

        with_them do
          it_behaves_like 'a query filtered by search level and membership'
        end
      end
    end

    context 'when multiple features are provided' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: :global,
          features: [:issues, :merge_requests]
        }
      end

      it 'applies both access levels to the query' do
        expected_access_filter = [
          {
            bool: {
              _name: "filters:permissions:global",
              minimum_should_match: 1,
              should: [{
                bool: {
                  must: contain_exactly(
                    {
                      terms: {
                        _name: "filters:permissions:global:visibility_level:public",
                        visibility_level: contain_exactly(::Gitlab::VisibilityLevel::PUBLIC)
                      }
                    }
                  ),
                  should: contain_exactly(
                    {
                      terms: {
                        _name: "filters:permissions:global:issues_access_level:enabled",
                        issues_access_level: contain_exactly(::ProjectFeature::ENABLED)
                      }
                    },
                    {
                      terms: {
                        _name: "filters:permissions:global:merge_requests_access_level:enabled",
                        merge_requests_access_level: contain_exactly(::ProjectFeature::ENABLED)
                      }
                    }
                  ),
                  minimum_should_match: 1
                }
              }]
            }
          }
        ]

        actual_filter = by_search_level_and_membership.dig(:query, :bool, :filter)
        expect(actual_filter).to match(expected_access_filter)
      end
    end

    def member_filter_for_namespace(namespace)
      {
        prefix: {
          traversal_ids: {
            _name: "filters:permissions:#{search_level}:ancestry_filter:descendants",
            value: namespace.elastic_namespace_ancestry
          }
        }
      }
    end

    def member_filter_for_projects(projects)
      {
        terms: {
          _name: "filters:permissions:#{search_level}:project:member",
          project_id: match_array(projects.map(&:id))
        }
      }
    end

    def user_public_access_filter
      { bool: {
        _name: "filters:permissions:#{search_level}",
        should: [public_and_internal_and_enabled_filter],
        minimum_should_match: 1
      } }
    end

    def admin_public_access_filter
      { bool: {
        _name: "filters:permissions:#{search_level}",
        should: [{
          bool: {
            should: contain_exactly(
              {
                terms: {
                  _name: "filters:permissions:#{search_level}:repository_access_level:enabled_or_private",
                  repository_access_level: contain_exactly(::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE)
                }
              }
            ),
            minimum_should_match: 1
          }
        }],
        minimum_should_match: 1
      } }
    end

    def no_user_public_access_filter
      { bool:
        { _name: "filters:permissions:#{search_level}",
          should: [public_filter],
          minimum_should_match: 1 } }
    end

    def public_filter
      {
        bool: {
          must: [
            {
              terms: {
                _name: "filters:permissions:#{search_level}:visibility_level:public",
                visibility_level: contain_exactly(::Gitlab::VisibilityLevel::PUBLIC)
              }
            }
          ],
          should: contain_exactly(
            {
              terms: {
                _name: "filters:permissions:#{search_level}:repository_access_level:enabled",
                repository_access_level: contain_exactly(::ProjectFeature::ENABLED)
              }
            }
          ),
          minimum_should_match: 1
        }
      }
    end

    def search_level_public_and_internal_access_filter
      { bool:
        { _name: "filters:permissions:#{search_level}",
          should: [public_and_internal_and_enabled_filter],
          minimum_should_match: 1 } }
    end

    def public_and_internal_and_enabled_filter
      {
        bool: {
          must: [
            {
              terms: {
                _name: "filters:permissions:#{search_level}:visibility_level:public_and_internal",
                visibility_level: contain_exactly(::Gitlab::VisibilityLevel::PUBLIC,
                  ::Gitlab::VisibilityLevel::INTERNAL)
              }
            }
          ],
          should: contain_exactly(
            {
              terms: {
                _name: "filters:permissions:#{search_level}:repository_access_level:enabled",
                repository_access_level: contain_exactly(::ProjectFeature::ENABLED)
              }
            }
          ),
          minimum_should_match: 1
        }
      }
    end

    def project_filter
      { bool:
        { _name: 'filters:level:project',
          must: { terms: { project_id: projects.map(&:id) } } } }
    end

    def group_filter
      groups_filter = groups.map do |group|
        {
          prefix: {
            traversal_ids: {
              _name: 'filters:level:group:ancestry_filter:descendants',
              value: group.elastic_namespace_ancestry
            }
          }
        }
      end

      {
        bool: {
          _name: 'filters:level:group',
          should: match_array(groups_filter),
          minimum_should_match: 1
        }
      }
    end

    def member_with_access_filter
      member_filter_array = []
      auth_groups.map do |group|
        member_filter_array << member_filter_for_namespace(group)
      end
      member_filter_array << member_filter_for_projects(auth_projects) if auth_projects.present?

      {
        bool: {
          _name: "filters:permissions:#{search_level}",
          minimum_should_match: 1,
          should: contain_exactly(
            public_and_internal_and_enabled_filter,
            {
              bool: {
                filter: [
                  {
                    bool: {
                      should: contain_exactly(
                        {
                          terms: {
                            _name: "filters:permissions:#{search_level}:repository_access_level:enabled_or_private",
                            repository_access_level: contain_exactly(::ProjectFeature::ENABLED,
                              ::ProjectFeature::PRIVATE)
                          }
                        }
                      ),
                      minimum_should_match: 1
                    }
                  }
                ],
                should: match_array(member_filter_array),
                minimum_should_match: 1
              }
            }
          )
        }
      }
    end

    def global_member_access_filter
      member_filter_array = auth_groups.map do |group|
        member_filter_for_namespace(group)
      end
      member_filter_array << member_filter_for_projects(auth_projects) if auth_projects.present?

      {
        bool: {
          filter: [
            {
              bool: {
                should: match_array([
                  {
                    terms: {
                      _name: "filters:permissions:#{search_level}:repository_access_level:enabled_or_private",
                      repository_access_level: contain_exactly(::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE)
                    }
                  }
                ]),
                minimum_should_match: 1
              }
            }
          ],
          should: match_array(member_filter_array),
          minimum_should_match: 1
        }
      }
    end
  end
end
