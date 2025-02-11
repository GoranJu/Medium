# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GlobalService, feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  let_it_be(:user) { create(:user) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_feature_flags(search_uses_match_queries: false)
  end

  it_behaves_like 'EE search service shared examples', ::Gitlab::SearchResults, ::Gitlab::Elastic::SearchResults do
    let(:scope) { nil }
    let(:service) { described_class.new(user, params) }
  end

  describe '#search_type' do
    let(:search_service) { described_class.new(user, scope: scope) }

    subject(:search_type) { search_service.search_type }

    using RSpec::Parameterized::TableSyntax

    where(:use_zoekt, :use_elasticsearch, :scope, :expected_type) do
      true   | true  | 'blobs'  | 'zoekt'
      false  | true  | 'blobs'  | 'advanced'
      false  | false | 'blobs'  | 'basic'
      true   | true  | 'issues' | 'advanced'
      true   | false | 'issues' | 'basic'
    end

    with_them do
      before do
        allow(search_service).to receive_messages(scope: scope, use_zoekt?: use_zoekt,
          use_elasticsearch?: use_elasticsearch)
      end

      it { is_expected.to eq(expected_type) }

      %w[basic advanced zoekt].each do |search_type|
        context "with search_type param #{search_type}" do
          let(:search_service) { described_class.new(user, { scope: scope, search_type: search_type }) }

          it { is_expected.to eq(search_type) }
        end
      end
    end
  end

  context 'for has_parent usage', :elastic do
    shared_examples 'search does not use has_parent' do |scope|
      let(:results) { described_class.new(nil, search: '*').execute.objects(scope) }
      let(:es_host) { Gitlab::CurrentSettings.elasticsearch_url.first }
      let(:search_url) { %r{#{es_host}/[\w-]+/_search} }

      it 'does not use joins to apply permissions' do
        request = a_request(:post, search_url).with do |req|
          expect(req.body).not_to include("has_parent")
        end

        results

        expect(request).to have_been_made
      end
    end

    it_behaves_like 'search does not use has_parent', 'merge_requests'
    it_behaves_like 'search does not use has_parent', 'issues'
    it_behaves_like 'search does not use has_parent', 'notes'
  end

  context 'when projects search has an empty search term', :elastic do
    subject { service.execute.objects('projects') }

    let(:service) { described_class.new(nil, search: nil) }

    it 'does not raise exception' do
      is_expected.to be_empty
    end
  end

  context 'for visibility', :elastic_delete_by_query do
    include_context 'ProjectPolicyTable context'

    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, namespace: group) }
    let(:projects) { [project] }

    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }

    context 'on merge request' do
      let!(:merge_request) { create :merge_request, target_project: project, source_project: project }
      let(:scope) { 'merge_requests' }
      let(:search) { merge_request.title }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_reporter_feature_access
      end

      with_them do
        it_behaves_like 'search respects visibility'
      end
    end

    context 'on note' do
      let(:scope) { 'notes' }
      let(:search) { note.note }

      context 'on issues' do
        let!(:note) { create :note_on_issue, project: project }
        let!(:confidential_note) do
          note_author_and_assignee = user || project.creator
          issue = create(:issue, project: project, assignees: [note_author_and_assignee])
          create(:note, note: note.note, confidential: true, project: project, noteable: issue,
            author: note_author_and_assignee)
        end

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_notes_feature_access
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end

      context 'on merge requests' do
        let!(:note) { create :note_on_merge_request, project: project }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_reporter_feature_access
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end

      context 'on commits' do
        let_it_be_with_reload(:project) { create(:project, :repository, namespace: group) }

        let!(:note) { create :note_on_commit, project: project }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access_and_non_private_project_only
        end

        with_them do
          before do
            project.repository.index_commits_and_blobs
          end

          it_behaves_like 'search respects visibility'
        end
      end

      context 'on snippets' do
        let!(:note) { create :note_on_project_snippet, project: project }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end
    end

    context 'on issue', :sidekiq_inline do # sidekiq needed for ElasticAssociationIndexerWorker
      let_it_be(:work_item) { create :work_item, project: project }

      let(:scope) { 'issues' }
      let(:search) { work_item.title }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access
      end

      with_them do
        before do
          Elastic::ProcessInitialBookkeepingService.track!(work_item)
          ensure_elasticsearch_index!
        end

        it_behaves_like 'search respects visibility'
      end
    end

    context 'on epic', :sidekiq_inline do # sidekiq is needed for the group association worker updates
      let(:scope) { 'epics' }
      let(:search) { 'chosen epic title' }
      let!(:epic) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'chosen epic title')
      end

      where(:group_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_epics_access
      end

      with_them do
        it 'respects visibility' do
          enable_admin_mode!(user_in_group) if admin_mode

          group.update!(visibility_level: Gitlab::VisibilityLevel.level_value(group_level.to_s))
          ensure_elasticsearch_index!
          expect_search_results(user_in_group, scope, expected_count: expected_count) do |user|
            described_class.new(user, search: search).execute
          end
        end
      end
    end

    context 'on wiki', :sidekiq_inline do
      let(:scope) { 'wiki_blobs' }
      let(:search) { 'term' }

      context 'for project wikis' do
        let_it_be_with_reload(:project) { create(:project, :wiki_repo) }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          before do
            project.wiki.create_page('test.md', "# #{search}")
            project.wiki.index_wiki_blobs
          end

          it_behaves_like 'search respects visibility'
        end
      end

      context 'for group wikis' do
        let_it_be_with_reload(:group) { create(:group, :public, :wiki_enabled) }
        let_it_be_with_reload(:group2) { create(:group, :public, :wiki_enabled) }
        let(:user) { create_user_from_membership(group, membership) }
        let_it_be(:group_wiki) { create(:group_wiki, container: group) }
        let_it_be(:group_wiki2) { create(:group_wiki, container: group2) }

        where(:group_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          before do
            [group_wiki, group_wiki2].each do |wiki|
              wiki.create_page('test.md', "# term")
              wiki.index_wiki_blobs
            end
            group2.add_member(user, membership) if %i[admin anonymous non_member].exclude?(membership)
          end

          it 'respects visibility' do
            enable_admin_mode!(user) if admin_mode
            [group, group2].each do |g|
              g.update!(
                visibility_level: Gitlab::VisibilityLevel.level_value(group_level.to_s),
                wiki_access_level: feature_access_level.to_s
              )
            end

            ensure_elasticsearch_index!

            expect_search_results(user, scope, expected_count: expected_count * 2) do |user|
              described_class.new(user, search: search).execute
            end
          end
        end
      end
    end

    context 'on milestone', :sidekiq_inline do
      let_it_be_with_reload(:milestone) { create :milestone, project: project }

      before do
        Elastic::ProcessInitialBookkeepingService.track!(milestone)
        ensure_elasticsearch_index!
      end

      where(:project_level, :issues_access_level, :merge_requests_access_level, :membership, :admin_mode,
        :expected_count) do
        permission_table_for_milestone_access
      end

      with_them do
        it 'respects visibility' do
          enable_admin_mode!(user) if admin_mode
          project.update!(
            visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s),
            issues_access_level: issues_access_level,
            merge_requests_access_level: merge_requests_access_level
          )
          ensure_elasticsearch_index!

          expect_search_results(user, 'milestones', expected_count: expected_count) do |user|
            described_class.new(user, search: milestone.title).execute
          end
        end
      end
    end

    context 'on project' do
      where(:project_level, :membership, :expected_count) do
        permission_table_for_project_access
      end

      with_them do
        it 'respects visibility' do
          project.update!(visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s))

          ensure_elasticsearch_index!

          expected_objects = expected_count == 1 ? [project] : []

          expect_search_results(
            user,
            'projects',
            expected_count: expected_count,
            expected_objects: expected_objects
          ) do |user|
            described_class.new(user, search: project.name).execute
          end
        end
      end
    end
  end

  context 'for sorting', :elastic do
    let_it_be_with_reload(:project) { create(:project, :public) }

    before do
      Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
      ensure_elasticsearch_index!
    end

    context 'on issue' do
      let(:scope) { 'issues' }

      let_it_be(:old_result) { create(:issue, project: project, title: 'sorted old', created_at: 1.month.ago) }
      let_it_be(:new_result) { create(:issue, project: project, title: 'sorted recent', created_at: 1.day.ago) }
      let_it_be(:very_old_result) do
        create(:issue, project: project, title: 'sorted very old', created_at: 1.year.ago)
      end

      let_it_be(:old_updated) { create(:issue, project: project, title: 'updated old', updated_at: 1.month.ago) }
      let_it_be(:new_updated) { create(:issue, project: project, title: 'updated recent', updated_at: 1.day.ago) }
      let_it_be(:very_old_updated) do
        create(:issue, project: project, title: 'updated very old', updated_at: 1.year.ago)
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, search: 'updated', sort: sort).execute }
      end
    end

    context 'on merge request' do
      let(:scope) { 'merge_requests' }

      let_it_be(:old_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'old-1', title: 'sorted old',
          created_at: 1.month.ago)
      end

      let_it_be(:new_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'new-1', title: 'sorted recent',
          created_at: 1.day.ago)
      end

      let_it_be(:very_old_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'very-old-1', title: 'sorted very old',
          created_at: 1.year.ago)
      end

      let_it_be(:old_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-old-1', title: 'updated old',
          updated_at: 1.month.ago)
      end

      let_it_be(:new_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-new-1',
          title: 'updated recent', updated_at: 1.day.ago)
      end

      let_it_be(:very_old_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-very-old-1',
          title: 'updated very old', updated_at: 1.year.ago)
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, search: 'updated', sort: sort).execute }
      end
    end
  end

  describe '#allowed_scopes' do
    context 'when ES is used' do
      it 'includes ES-specific scopes' do
        expect(described_class.new(user, {}).allowed_scopes).to include('commits')
      end
    end

    context 'when elasticearch_search is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false)
      end

      it 'does not include ES-specific scopes' do
        expect(described_class.new(user, {}).allowed_scopes).not_to include('commits')
      end
    end

    context 'when elasticsearch_limit_indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      context 'when advanced_global_search_for_limited_indexing feature flag is disabled' do
        before do
          stub_feature_flags(advanced_global_search_for_limited_indexing: false)
        end

        it 'does not include ES-specific scopes' do
          expect(described_class.new(user, {}).allowed_scopes).not_to include('commits')
        end
      end

      context 'when advanced_global_search_for_limited_indexing feature flag is enabled' do
        it 'includes ES-specific scopes' do
          expect(described_class.new(user, {}).allowed_scopes).to include('commits')
        end
      end
    end

    context 'for blobs scope' do
      context 'when elasticearch_search is disabled and zoekt is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: false)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(false)
        end

        it 'does not include blobs scope' do
          expect(described_class.new(user, {}).allowed_scopes).not_to include('blobs')
        end
      end

      context 'when elasticsearch_search is enabled and zoekt is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: true)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(false)
        end

        it 'includes blobs scope' do
          expect(described_class.new(user, {}).allowed_scopes).to include('blobs')
        end
      end

      context 'when elasticsearch_search is disabled and zoekt is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: false)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(true)
        end

        it 'includes blobs scope' do
          expect(described_class.new(user, {}).allowed_scopes).to include('blobs')
        end
      end
    end
  end

  describe '#elastic_projects' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:another_project) { create(:project) }
    let_it_be(:non_admin_user) { create_user_from_membership(project, :developer) }
    let_it_be(:admin) { create(:admin) }

    let(:service) { described_class.new(user, {}) }
    let(:elastic_projects) { service.elastic_projects }

    context 'when the user is an admin' do
      let(:user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it 'returns :any' do
          expect(elastic_projects).to eq(:any)
        end
      end

      context 'when admin mode is disabled' do
        it 'returns empty array' do
          expect(elastic_projects).to eq([])
        end
      end
    end

    context 'when the user is not an admin' do
      let(:user) { non_admin_user }

      it 'returns the projects the user has access to' do
        expect(elastic_projects).to eq([project.id])
      end
    end

    context 'when there is no user' do
      let(:user) { nil }

      it 'returns empty array' do
        expect(elastic_projects).to eq([])
      end
    end
  end

  context 'on confidential notes' do
    let_it_be(:project) { create(:project, :public, :repository) }

    context 'with notes on issues' do
      let_it_be(:noteable) { create(:issue, project: project) }

      it_behaves_like 'search confidential notes shared examples', :note_on_issue
    end
  end
end
