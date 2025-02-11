# frozen_string_literal: true

RSpec.shared_examples 'does not hit Elasticsearch twice for objects and counts' do |scopes|
  scopes.each do |scope|
    context "for scope #{scope}", :elastic, :request_store, feature_category: :global_search do
      before do
        allow(::Gitlab::PerformanceBar).to receive(:enabled_for_request?).and_return(true)
      end

      it 'makes 1 Elasticsearch query' do
        # We want to warm the cache for checking migrations have run since we
        # don't want to count these requests as searches
        allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
        warm_elasticsearch_migrations_cache!
        ::Gitlab::SafeRequestStore.clear!

        results.objects(scope)
        results.public_send(:"#{scope}_count")

        request = ::Gitlab::Instrumentation::ElasticsearchTransport.detail_store.first

        expect(::Gitlab::Instrumentation::ElasticsearchTransport.get_request_count).to eq(1)
        expect(request.dig(:params, :timeout)).to eq('30s')
      end
    end
  end
end

RSpec.shared_examples 'does not load results for count only queries' do |scopes|
  scopes.each do |scope|
    context "for scope #{scope}", :elastic, :request_store, feature_category: :global_search do
      before do
        allow(::Gitlab::PerformanceBar).to receive(:enabled_for_request?).and_return(true)
      end

      it 'makes count query' do
        # We want to warm the cache for checking migrations have run since we
        # don't want to count these requests as searches
        allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
        warm_elasticsearch_migrations_cache!
        ::Gitlab::SafeRequestStore.clear!

        results.public_send(:"#{scope}_count")

        request = ::Gitlab::Instrumentation::ElasticsearchTransport.detail_store.first

        expect(request.dig(:body, :size)).to eq(0)
        expect(request[:highlight]).to be_blank
        expect(request.dig(:params, :timeout)).to eq('1s')
      end
    end
  end
end

RSpec.shared_examples 'loads expected aggregations' do
  let(:query) { 'hello world' }

  it 'returns the expected aggregations', feature_category: :global_search do
    expect(aggregations).to be_kind_of(Array)

    if expected_aggregation_name && (!feature_flag || feature_enabled)
      expect(aggregations.size).to eq(1)
      expect(aggregations.first.name).to eq(expected_aggregation_name)
    else
      expect(aggregations).to be_kind_of(Array)
      expect(aggregations).to be_empty
    end
  end
end

RSpec.shared_examples 'namespace ancestry_filter for aggregations' do
  let(:query_name) { "#{scope.singularize}:authorized:namespace:ancestry_filter:descendants" }

  before do
    group.add_developer(user)
  end

  it 'includes authorized:namespace:ancestry_filter:descendants name query' do
    results.aggregations(scope)
    assert_named_queries(query_name)
  end
end

RSpec.shared_examples_for 'a paginated object' do |object_type|
  let(:results) { described_class.new(user, query, limit_project_ids) }

  it 'does not explode when given a page as a string' do
    expect { results.objects(object_type, page: "2") }.not_to raise_error
  end

  it 'paginates' do
    objects = results.objects(object_type, page: 2)
    expect(objects).to respond_to(:total_count, :limit, :offset)
    expect(objects.offset_value).to eq(20)
  end

  it 'uses the per_page value if passed' do
    objects = results.objects(object_type, page: 5, per_page: 1)
    expect(objects.offset_value).to eq(4)
  end
end
