# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupService, feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_feature_flags(search_uses_match_queries: false)
  end

  it_behaves_like 'EE search service shared examples', ::Gitlab::GroupSearchResults,
    ::Gitlab::Elastic::GroupSearchResults do
    let(:scope) { group }
    let(:service) { described_class.new(user, scope, params) }
  end

  describe '#search_type' do
    let(:search_service) { described_class.new(user, group, scope: scope) }

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
          let(:search_service) do
            described_class.new(user, group, { scope: scope, search_type: search_type })
          end

          it { is_expected.to eq(search_type) }
        end
      end
    end
  end

  describe 'group search', :elastic do
    let_it_be(:term) { "RandomName" }
    let_it_be(:nested_group) { create(:group, :nested) }

    # These projects shouldn't be found
    let_it_be(:outside_project) { create(:project, :public, name: "Outside #{term}") }
    let_it_be(:private_project) do
      create(:project, :private, namespace: nested_group, name: "Private #{term}")
    end

    let_it_be(:other_project) { create(:project, :public, namespace: nested_group, name: 'OtherProject') }

    # These projects should be found
    let_it_be(:project1) { create(:project, :internal, namespace: nested_group, name: "Inner #{term} 1") }
    let_it_be(:project2) { create(:project, :internal, namespace: nested_group, name: "Inner #{term} 2") }
    let_it_be(:project3) do
      create(:project, :internal, namespace: nested_group.parent, name: "Outer #{term}")
    end

    let(:results) { described_class.new(user, search_group, search: term).execute }

    before do
      # Ensure these are present when the index is refreshed
      Elastic::ProcessInitialBookkeepingService.track!(
        outside_project, private_project, other_project, project1, project2, project3
      )

      ensure_elasticsearch_index!
    end

    context 'when finding projects by name' do
      subject { results.objects('projects') }

      context 'in parent group' do
        let(:search_group) { nested_group.parent }

        it { is_expected.to match_array([project1, project2, project3]) }
      end

      context 'in subgroup' do
        let(:search_group) { nested_group }

        it { is_expected.to match_array([project1, project2]) }
      end
    end
  end

  describe '#elasticsearchable_scope' do
    let(:service) { described_class.new(user, group, scope: scope) }
    let(:scope) { 'blobs' }

    it 'is set to group' do
      expect(service.elasticsearchable_scope).to eq(group)
    end

    context 'when the scope is users' do
      let(:scope) { 'users' }

      it 'is nil' do
        expect(service.elasticsearchable_scope).to be_nil
      end
    end
  end

  describe '#zoekt_node_id' do
    let(:scope) { 'blobs' }
    let_it_be(:node) { create(:zoekt_node) }
    let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: group.root_ancestor) }
    let_it_be(:root_id) { group.root_ancestor.id }

    before do
      create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, node: node, namespace_id: root_id)
    end

    subject { described_class.new(user, group, scope: scope).zoekt_node_id }

    it { is_expected.to be_nil }
  end

  context 'when searching with Zoekt', :zoekt_settings_enabled do
    let(:service) do
      described_class.new(user, group, search: 'foobar', scope: scope, page: page, source: source)
    end

    let(:source) { nil }
    let(:use_zoekt) { true }
    let(:scope) { 'blobs' }
    let(:page) { nil }
    let_it_be(:zoekt_nodes) { create_list(:zoekt_node, 2) }
    let(:circuit_breaker) { instance_double(::Search::Zoekt::CircuitBreaker) }
    let(:circuit_breaker_operational) { true }

    before do
      allow(group).to receive_messages(use_zoekt?: use_zoekt, search_code_with_zoekt?: use_zoekt)
      zoekt_ensure_namespace_indexed!(group)

      allow(service).to receive(:zoekt_nodes).and_return zoekt_nodes
      allow(::Search::Zoekt::CircuitBreaker).to receive(:new).with(*zoekt_nodes).and_return(circuit_breaker)
      allow(circuit_breaker).to receive(:operational?).and_return(circuit_breaker_operational)
    end

    it 'returns a Search::Zoekt::SearchResults' do
      expect(service.use_zoekt?).to be(true)
      expect(service.zoekt_searchable_scope).to eq(group)
      expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
    end

    context 'when advanced search is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
      end

      context 'and all replicas are in ready state' do
        before do
          group.zoekt_enabled_namespace.replicas.update_all(state: :ready)
        end

        it 'returns a Search::Zoekt::SearchResults' do
          expect(service.use_zoekt?).to be(true)
          expect(service.zoekt_searchable_scope).to eq(group)
          expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
        end
      end
    end

    context 'when group does not have Zoekt enabled' do
      let(:use_zoekt) { false }

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when scope is not blobs' do
      let(:scope) { 'issues' }

      it 'does not search with Zoekt' do
        expect(service.search_type).not_to eq('zoekt')
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when basic search is requested' do
      let(:service) do
        described_class.new(user, group, search: 'foobar', scope: scope,
          page: page, source: source, search_type: 'basic')
      end

      it 'does not search with Zoekt' do
        expect(service.search_type).to eq('basic')
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when application setting zoekt_search_enabled is disabled' do
      before do
        stub_ee_application_setting(zoekt_search_enabled: false)
      end

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when requesting the first page' do
      let(:page) { 1 }

      it 'searches with Zoekt' do
        expect(service.use_zoekt?).to be(true)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when requesting a page other than the first' do
      let(:page) { 2 }

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(true)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when zoekt_code_search licensed feature is disabled' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when circuit breaker is tripped' do
      let(:circuit_breaker_operational) { false }

      it 'does not search with Zoekt' do
        expect(service).not_to be_use_zoekt
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when search comes from API' do
      let(:source) { 'api' }

      it 'searches with Zoekt' do
        expect(service.use_zoekt?).to be(true)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end

      context 'when zoekt_search_api is disabled' do
        before do
          stub_feature_flags(zoekt_search_api: false)
        end

        it 'does not search with Zoekt' do
          expect(service.use_zoekt?).to be(false)
          expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
        end
      end
    end

    context 'when feature flag disable_zoekt_search_for_saas is enabled' do
      before do
        stub_feature_flags(disable_zoekt_search_for_saas: true)
      end

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end
  end

  describe 'visibility', :elastic_delete_by_query do
    include_context 'ProjectPolicyTable context'

    let_it_be_with_refind(:project) { create(:project, :repository, namespace: group) }
    let_it_be_with_refind(:project2) { create(:project, :repository) }

    let(:user) { create_user_from_membership(project, membership) }
    let(:projects) { [project, project2] }
    let(:search_level) { group }

    context 'for merge requests' do
      let_it_be_with_reload(:merge_request) do
        create :merge_request, target_project: project, source_project: project
      end

      let_it_be_with_reload(:merge_request2) do
        create :merge_request, target_project: project2, source_project: project2, title: merge_request.title
      end

      let(:scope) { 'merge_requests' }
      let(:search) { merge_request.title }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_reporter_feature_access
      end

      with_them do
        before do
          Elastic::ProcessInitialBookkeepingService.track!(merge_request, merge_request2)
          ensure_elasticsearch_index!
        end

        it_behaves_like 'search respects visibility'
      end
    end

    context 'for notes' do
      let(:scope) { 'notes' }
      let(:search) { note.note }

      context 'on issues' do
        let_it_be(:issue) { create(:issue, project: project) }
        let_it_be(:issue2) { create(:issue, project: project2) }
        let_it_be(:note) { create :note, noteable: issue, project: project }
        let_it_be(:note2) { create :note, noteable: issue2, project: project2, note: note.note }
        let_it_be(:confidential_note) do
          note_author_and_assignee = project.creator
          issue2 = create(:issue, project: project, assignees: [note_author_and_assignee])
          create(:note, note: note.note, confidential: true,
            project: project, noteable: issue2, author: note_author_and_assignee)
        end

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_notes_feature_access
        end

        with_them do
          before do
            Elastic::ProcessInitialBookkeepingService.track!(note, note2, confidential_note)
            ensure_elasticsearch_index!
          end

          it_behaves_like 'search respects visibility'
        end
      end

      context 'on merge requests' do
        let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
        let_it_be(:merge_request2) { create(:merge_request, target_project: project2, source_project: project2) }
        let_it_be(:note) { create :note, noteable: merge_request, project: project }
        let_it_be(:note2) { create :note, noteable: merge_request2, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_reporter_feature_access
        end

        with_them do
          before do
            Elastic::ProcessInitialBookkeepingService.track!(note, note2)
            ensure_elasticsearch_index!
          end

          it_behaves_like 'search respects visibility'
        end
      end

      context 'on commits' do
        let_it_be(:note) { create :note_on_commit, project: project }
        let_it_be(:note2) { create :note_on_commit, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access_and_non_private_project_only
        end

        with_them do
          before do
            Elastic::ProcessInitialBookkeepingService.track!(note, note2)
            ensure_elasticsearch_index!
          end

          it_behaves_like 'search respects visibility'
        end
      end

      context 'on snippets' do
        let_it_be(:note) { create :note_on_project_snippet, project: project }
        let_it_be(:note2) { create :note_on_project_snippet, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          before do
            Elastic::ProcessInitialBookkeepingService.track!(note, note2)
            ensure_elasticsearch_index!
          end

          it_behaves_like 'search respects visibility'
        end
      end
    end

    context 'for issues', :sidekiq_inline do # sidekiq needed for ElasticAssociationIndexerWorker
      let_it_be(:work_item) { create(:work_item, project: project) }
      let_it_be(:work_item2) { create(:work_item, project: project2, title: work_item.title) }

      let(:scope) { 'issues' }
      let(:search) { work_item.title }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access
      end

      with_them do
        before do
          Elastic::ProcessInitialBookkeepingService.track!(work_item, work_item2)
          ensure_elasticsearch_index!
        end

        it_behaves_like 'search respects visibility'
      end
    end

    context 'for milestones' do
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
            described_class.new(user, group, search: milestone.title).execute
          end
        end
      end
    end

    context 'for projects' do
      let_it_be_with_reload(:project) { create(:project, namespace: group) }

      where(:project_level, :membership, :expected_count) do
        permission_table_for_project_access
      end

      with_them do
        it 'respects visibility' do
          project.update!(visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s))

          Elastic::ProcessInitialBookkeepingService.track!(project)
          ensure_elasticsearch_index!

          expected_objects = expected_count == 1 ? [project] : []

          expect_search_results(
            user,
            'projects',
            expected_count: expected_count,
            expected_objects: expected_objects
          ) do |user|
            described_class.new(user, group, search: project.name).execute
          end
        end
      end
    end
  end

  context 'when sorting', :elastic do
    context 'for issues' do
      let_it_be(:project) { create(:project, :public, group: group) }

      let_it_be(:old_result) { create(:work_item, project: project, title: 'sorted old', created_at: 1.month.ago) }
      let_it_be(:new_result) { create(:work_item, project: project, title: 'sorted recent', created_at: 1.day.ago) }
      let_it_be(:very_old_result) do
        create(:work_item, project: project, title: 'sorted very old', created_at: 1.year.ago)
      end

      let_it_be(:old_updated) { create(:work_item, project: project, title: 'updated old', updated_at: 1.month.ago) }
      let_it_be(:new_updated) { create(:work_item, project: project, title: 'updated recent', updated_at: 1.day.ago) }
      let_it_be(:very_old_updated) do
        create(:work_item, project: project, title: 'updated very old', updated_at: 1.year.ago)
      end

      let(:results_created) { described_class.new(nil, group, search: 'sorted', sort: sort).execute }
      let(:results_updated) { described_class.new(nil, group, search: 'updated', sort: sort).execute }

      let(:scope) { 'issues' }

      before do
        Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted'
    end

    context 'for merge requests' do
      let(:scope) { 'merge_requests' }
      let_it_be(:project) { create(:project, :public, group: group) }

      let_it_be(:new_result) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'new-1', title: 'sorted recent', created_at: 1.day.ago)
      end

      let_it_be(:old_result) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'old-1', title: 'sorted old', created_at: 1.month.ago)
      end

      let_it_be(:very_old_result) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'very-old-1', title: 'sorted very old', created_at: 1.year.ago)
      end

      let_it_be(:new_updated) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'updated-new-1', title: 'updated recent', updated_at: 1.day.ago)
      end

      let_it_be(:old_updated) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'updated-old-1', title: 'updated old', updated_at: 1.month.ago)
      end

      let_it_be(:very_old_updated) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'updated-very-old-1', title: 'updated very old', updated_at: 1.year.ago)
      end

      before do
        Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, group, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, group, search: 'updated', sort: sort).execute }
      end
    end

    context 'for group level work_items' do
      let(:scope) { 'epics' }
      let_it_be(:member) { create(:group_member, :owner, group: group, user: user) }

      let_it_be(:old_result) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'sorted old',
          created_at: 1.month.ago)
      end

      let_it_be(:new_result) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'sorted recent',
          created_at: 1.day.ago)
      end

      let_it_be(:very_old_result) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'sorted very old',
          created_at: 1.year.ago)
      end

      let_it_be(:old_updated) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'updated old',
          updated_at: 1.month.ago)
      end

      let_it_be(:new_updated) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'updated recent',
          updated_at: 1.day.ago)
      end

      let_it_be(:very_old_updated) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'updated very old',
          updated_at: 1.year.ago)
      end

      let(:results_created) { described_class.new(user, group, search: 'sorted', sort: sort).execute }
      let(:results_updated) { described_class.new(user, group, search: 'updated', sort: sort).execute }

      before do
        stub_licensed_features(epics: true)
        Elastic::ProcessInitialBookkeepingService.track!(old_result, new_result, very_old_result,
          old_updated, new_updated, very_old_updated
        )
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted'
    end
  end

  describe '#allowed_scopes' do
    let_it_be(:group) { create(:group) }
    let(:service) { described_class.new(user, group, {}) }

    subject(:allowed_scopes) { service.allowed_scopes }

    context 'for blobs scope' do
      context 'when elasticearch_search is disabled and zoekt is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: false)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(false)
        end

        it { is_expected.not_to include('blobs') }
      end

      context 'when elasticsearch_search is enabled and zoekt is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: true)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(false)
        end

        it { is_expected.to include('blobs') }
      end

      context 'when elasticsearch_search is disabled and zoekt is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: false)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(true)
          allow(::Search::Zoekt).to receive(:search?).with(group).and_return(true)
          allow(service).to receive(:zoekt_node_available_for_search?).and_return(true)
        end

        it { is_expected.to include('blobs') }

        context 'and zoekt node is not available' do
          before do
            allow(service).to receive(:zoekt_node_available_for_search?).and_return(false)
          end

          it { is_expected.not_to include('blobs') }
        end

        context 'and the group does is not enabled for zoekt' do
          before do
            allow(::Search::Zoekt).to receive(:search?).with(group).and_return(false)
          end

          it { is_expected.not_to include('blobs') }
        end
      end
    end

    context 'for epics scope' do
      before do
        stub_licensed_features(epics: epics_available)
      end

      context 'when epics available' do
        let(:epics_available) { true }

        it 'does include epics to allowed_scopes' do
          expect(allowed_scopes).to include('epics')
        end
      end

      context 'when epics is not available' do
        let(:epics_available) { false }

        it 'does not include epics to allowed_scopes' do
          expect(allowed_scopes).not_to include('epics')
        end
      end
    end
  end
end
