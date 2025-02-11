# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::WorkItemQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:base_options) do
    {
      current_user: user,
      project_ids: project_ids,
      group_ids: [],
      klass: Issue, # For rendering the UI
      index_name: ::Search::Elastic::References::WorkItem.index,
      not_work_item_type_ids: [::WorkItems::Type.find_by_name(::WorkItems::Type::TYPE_NAMES[:epic]).id],
      public_and_internal_projects: false,
      search_level: 'global'
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      work_item:multi_match:or:search_terms
      work_item:multi_match:and:search_terms
      work_item:multi_match_phrase:search_terms
      filters:permissions:global
      filters:not_hidden
      filters:not_work_item_type_ids
      filters:non_archived
      filters:non_confidential
      filters:confidential
      filters:confidential:as_author
      filters:confidential:as_assignee
      filters:confidential:project:membership:id
    ])
  end

  describe 'query' do
    context 'when query is an iid' do
      let(:query) { '#1' }

      it 'returns the expected query' do
        assert_names_in_query(build, with: %w[work_item:related:iid doc:is_a:work_item])
      end
    end

    context 'when query is text' do
      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[work_item:multi_match:or:search_terms
            work_item:multi_match:and:search_terms
            work_item:multi_match_phrase:search_terms],
          without: %w[work_item:match:search_terms])
      end

      context 'when advanced query syntax is used' do
        let(:query) { 'foo -default' }

        it 'returns the expected query' do
          assert_names_in_query(build,
            with: %w[work_item:match:search_terms],
            without: %w[work_item:multi_match:or:search_terms
              work_item:multi_match:and:search_terms
              work_item:multi_match_phrase:search_terms])
        end
      end

      context 'when search_uses_match_queries is false' do
        before do
          stub_feature_flags(search_uses_match_queries: false)
        end

        it 'returns the expected query' do
          assert_names_in_query(build,
            with: %w[work_item:match:search_terms],
            without: %w[work_item:multi_match:or:search_terms
              work_item:multi_match:and:search_terms
              work_item:multi_match_phrase:search_terms])
        end
      end

      context 'when search_uses_note_fields feature flag is disabled' do
        before do
          stub_feature_flags(advanced_search_work_item_uses_note_fields: false)
        end

        it 'returns the expected query without the note fields' do
          assert_fields_in_query(build, without: %w[notes notes_internal])
        end
      end

      it 'returns the expected query with the note fields' do
        assert_fields_in_query(build, with: %w[notes notes_internal])
      end
    end
  end

  describe 'hybrid search' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:project) { create(:project) }
    let(:helper) { instance_double(Gitlab::Elastic::Helper) }
    let(:project_ids) { [project.id] }
    let(:embedding_service) { instance_double(Gitlab::Llm::VertexAi::Embeddings::Text) }
    let(:mock_embedding) { [1, 2, 3] }
    let(:hybrid_similarity) { 0.5 }
    let(:hybrid_boost) { 0.5 }
    let(:query) { 'test with long query' }
    let(:options) { base_options.merge(hybrid_similarity: hybrid_similarity, hybrid_boost: hybrid_boost) }

    before do
      allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(true)
      allow(user).to receive(:any_group_with_ai_available?).and_return(true)
      allow(Gitlab::Llm::VertexAi::Embeddings::Text).to receive(:new).and_return(embedding_service)
      allow(embedding_service).to receive(:execute).and_return(mock_embedding)
      allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:vectors_supported?).and_return(true)
    end

    context 'when we cannot generate embeddings' do
      before do
        allow(embedding_service).to receive(:execute).and_return(nil)
      end

      it 'does not add a knn query' do
        expect(build).not_to have_key(:knn)
      end
    end

    context 'when we have both opensearch and elasticsearch not running' do
      before do
        allow(helper).to receive(:vectors_supported?).with(:elasticsearch).and_return(false)
        allow(helper).to receive(:vectors_supported?).with(:opensearch).and_return(false)
      end

      it 'does not add a knn query' do
        expect(build).not_to have_key(:knn)
      end
    end

    context 'when we have opensearch running' do
      before do
        allow(helper).to receive(:vectors_supported?).with(:elasticsearch).and_return(false)
        allow(helper).to receive(:vectors_supported?).with(:opensearch).and_return(true)
      end

      it 'add knn query for opensearch' do
        query = build
        os_knn_query = {
          knn: {
            embedding_0: {
              k: 25,
              vector: mock_embedding
            }
          }
        }
        expect(query[:query][:bool][:should]).to include(os_knn_query)
      end

      context 'when simple_query_string is used' do
        before do
          stub_feature_flags(search_uses_match_queries: false)
        end

        it 'applies boost to the query' do
          query_hash = build
          os_knn_query = {
            knn: {
              embedding_0: {
                k: 25,
                vector: mock_embedding
              }
            }
          }
          simple_qs_with_boost = {
            simple_query_string: {
              _name: "work_item:match:search_terms",
              fields: ["iid^50", "title^2", "description", "notes", "notes_internal"],
              query: query,
              lenient: true,
              default_operator: :and,
              boost: 0.2
            }
          }
          expect(query_hash[:query][:bool][:should]).to include(simple_qs_with_boost, os_knn_query)
        end
      end
    end

    shared_examples 'without hybrid search query' do
      it 'does not add a knn query' do
        expect(build).not_to have_key(:knn)
      end
    end

    it 'adds a knn query with the same filters as the bool filters' do
      query = build

      expect(query).to have_key(:knn)
      expect(query[:knn][:query_vector]).to eq(mock_embedding)
      expect(query[:knn][:similarity]).to eq(hybrid_similarity)
      expect(query[:knn][:boost]).to eq(hybrid_boost)

      expected_filters = %w[
        filters:permissions:global
        filters:non_confidential
        filters:confidential
        filters:confidential:as_author
        filters:confidential:as_assignee
        filters:confidential:project:membership:id
      ]

      knn_filter = query[:knn][:filter]
      query_without_knn = query.except(:knn)

      assert_names_in_query(knn_filter, with: expected_filters)
      assert_names_in_query(query_without_knn, with: expected_filters)
    end

    context 'when query is short' do
      let(:query) { 'foo' }

      it_behaves_like 'without hybrid search query'
    end

    context 'if project_ids is not specified' do
      let(:project_ids) { [] }

      it_behaves_like 'without hybrid search query'
    end

    context 'if user is not authorized to perform ai actions' do
      before do
        allow(user).to receive(:any_group_with_ai_available?).and_return(false)
      end

      it_behaves_like 'without hybrid search query'
    end

    context 'with embeddings not available' do
      where(:hybrid_work_item_search, :ai_global_switch, :work_item_embedding, :ai_available) do
        false | false | false | false
        true  | false | false | false
        false | true  | false | false
        false | false | true  | false
        false | false | false | true
        false | false | false | false
      end

      with_them do
        before do
          stub_feature_flags(search_work_items_hybrid_search: hybrid_work_item_search)
          stub_feature_flags(ai_global_switch: ai_global_switch)
          stub_feature_flags(elasticsearch_work_item_embedding: work_item_embedding)
          allow(Gitlab::Saas).to receive(:feature_available?).and_return(ai_available)
        end

        it_behaves_like 'without hybrid search query'
      end
    end

    context 'when the query is with fields' do
      let(:options) { base_options.merge(fields: ['title']) }

      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[work_item:multi_match:or:search_terms
            work_item:multi_match:and:search_terms
            work_item:multi_match_phrase:search_terms],
          without: %w[work_item:match:search_terms])
        assert_fields_in_query(build, with: %w[title])
      end

      context 'when search_uses_match_queries is false' do
        before do
          stub_feature_flags(search_uses_match_queries: false)
        end

        it 'returns the expected query' do
          assert_names_in_query(build, with: %w[work_item:match:search_terms])
          assert_fields_in_query(build, with: %w[title], without: %w[iid description])
        end
      end
    end
  end

  describe 'filters' do
    let_it_be(:group) { create(:group) }
    let_it_be(:private_project) { create(:project, :private, group: group) }
    let_it_be(:authorized_project) { create(:project, developers: [user], group: group) }
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'
    it_behaves_like 'a query filtered by hidden'
    it_behaves_like 'a query filtered by state'
    it_behaves_like 'a query filtered by confidentiality'

    describe 'authorization' do
      it_behaves_like 'a query filtered by project authorization'
    end

    describe 'labels' do
      let_it_be(:label) { create(:label, project: authorized_project, title: 'My Label') }

      it 'does not include labels filter by default' do
        assert_names_in_query(build, without: %w[filters:label_ids])
      end

      context 'when label_name option is provided' do
        let(:options) { base_options.merge(label_name: [label.name]) }

        it 'applies label filters' do
          assert_names_in_query(build, with: %w[filters:label_ids])
        end
      end
    end
  end

  it_behaves_like 'a sorted query'

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
    it_behaves_like 'a query that is paginated'
  end
end
