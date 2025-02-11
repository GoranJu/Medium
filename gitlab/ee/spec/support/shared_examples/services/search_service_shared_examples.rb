# frozen_string_literal: true

RSpec.shared_examples 'search respects visibility' do
  it 'respects visibility' do
    enable_admin_mode!(user) if admin_mode
    projects.each do |project|
      update_feature_access_level(
        project,
        feature_access_level,
        visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s)
      )
    end
    ensure_elasticsearch_index!

    expect_search_results(user, scope, expected_count: expected_count) do |user|
      if described_class.eql?(Search::GlobalService)
        described_class.new(user, search: search).execute
      else
        described_class.new(user, search_level, search: search).execute
      end
    end
  end
end

RSpec.shared_examples 'EE search service shared examples' do |normal_results, elasticsearch_results|
  let(:params) { { search: '*' } }

  describe '#use_elasticsearch?' do
    it 'delegates to Gitlab::CurrentSettings.search_using_elasticsearch?' do
      expect(Gitlab::CurrentSettings)
        .to receive(:search_using_elasticsearch?)
        .with(scope: scope)
        .and_return(:value)

      expect(service.use_elasticsearch?).to eq(:value)
    end
  end

  describe '#execute' do
    subject { service.execute }

    it 'returns an Elastic result object when elasticsearch is enabled' do
      expect(Gitlab::CurrentSettings)
        .to receive(:search_using_elasticsearch?)
        .with(scope: scope)
        .at_least(:once)
        .and_return(true)

      is_expected.to be_a(elasticsearch_results)
    end

    it 'returns an ordinary result object when elasticsearch is disabled' do
      expect(Gitlab::CurrentSettings)
        .to receive(:search_using_elasticsearch?)
        .with(scope: scope)
        .at_least(:once)
        .and_return(false)

      is_expected.to be_a(normal_results)
    end

    context 'advanced syntax queries for all scopes', :elastic, :sidekiq_inline do
      queries = [
        '"display bug"',
        'bug -display',
        'bug display | sound',
        'bug | (display +sound)',
        'bug find_by_*',
        'argument \-last'
      ]

      scopes = if elasticsearch_results == ::Gitlab::Elastic::SnippetSearchResults
                 %w[
                   snippet_titles
                 ]
               else
                 %w[
                   merge_requests
                   notes
                   commits
                   blobs
                   projects
                   issues
                   wiki_blobs
                   milestones
                 ]
               end

      queries.each do |query|
        scopes.each do |scope|
          context "with query #{query} and scope #{scope}" do
            let(:params) { { search: query, scope: scope } }

            it "allows advanced query" do
              allow(Gitlab::CurrentSettings)
                .to receive(:search_using_elasticsearch?)
                .and_return(true)

              ensure_elasticsearch_index!

              results = subject
              expect(results.objects(scope)).to be_kind_of(Enumerable)
            end
          end
        end
      end
    end
  end
end

RSpec.shared_examples 'can search by title for miscellaneous cases' do |type|
  let_it_be(:searched_project) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:searched_group) { create(:group, :public) }
  let(:records_count) { 2 }

  def create_records!(type)
    case type
    when 'epics'
      create_list(:work_item, records_count, :group_level, :epic_with_legacy_epic, namespace: searched_group)
    when 'issues'
      create_list(:issue, records_count, project: searched_project)
    when 'merge_requests'
      records = []
      records_count.times { |i| records << create(:merge_request, source_branch: i, source_project: searched_project) }
      records
    end
  end

  def results(type, query)
    case type
    when 'epics'
      described_class.new(user, query, searched_group.projects.pluck_primary_key, group: searched_group)
    else
      described_class.new(user, query, [searched_project.id])
    end
  end

  # rubocop:disable RSpec/InstanceVariable -- Want to reuse the @records
  before do
    @records = create_records!(type)
  end

  it 'handles plural words through algorithmic stemming', :aggregate_failures do
    @records[0].update!(title: 'remove :title attribute from submit buttons to prevent un-styled tooltips')
    @records[1].update!(title: 'smarter submit behavior for buttons groups')
    ensure_elasticsearch_index!
    results = results(type, 'button')
    expect(results.objects(type)).to match_array(@records)
  end

  it 'handles if title has umlauts', :aggregate_failures do
    @records[0].update!(title: 'köln')
    @records[1].update!(title: 'kǒln')
    ensure_elasticsearch_index!
    results = results(type, 'koln')
    expect(results.objects(type)).to match_array(@records)
  end

  it 'handles if title has dots', :aggregate_failures do
    @records[0].update!(title: 'with.dot.title')
    @records[1].update!(title: 'there is.dot')
    ensure_elasticsearch_index!
    results = results(type, 'dot')
    expect(results.objects(type)).to match_array(@records)
  end

  it 'handles if title has underscore', :aggregate_failures do
    @records[0].update!(title: 'with_underscore_text')
    @records[1].update!(title: 'some_underscore')
    ensure_elasticsearch_index!
    results = results(type, 'underscore')
    expect(results.objects(type)).to match_array(@records)
  end

  it 'handles if title has camelcase', :aggregate_failures do
    @records[0].update!(title: 'withCamelcaseTitle')
    @records[1].update!(title: 'CamelcaseText')
    ensure_elasticsearch_index!
    results = results(type, 'Camelcase')
    expect(results.objects(type)).to match_array(@records)
  end
  # rubocop:enable RSpec/InstanceVariable
end
