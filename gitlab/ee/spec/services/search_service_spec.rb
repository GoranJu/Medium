# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchService, feature_category: :global_search do
  describe '#search_objects' do
    let(:scope) { nil }
    let(:page) { 1 }
    let(:per_page) { described_class::DEFAULT_PER_PAGE }

    subject(:search_service) { described_class.new(user, search: search, scope: scope, page: page, per_page: per_page) }

    it_behaves_like 'a redacted search results'
  end

  describe '#projects' do
    let_it_be(:user) { create(:user) }
    let_it_be(:accessible_project) { create(:project, :public) }
    let_it_be(:inaccessible_project) { create(:project, :private) }

    context 'when all projects are accessible' do
      let_it_be(:accessible_project_2) { create(:project, :public) }

      it 'returns the project' do
        project_ids = [accessible_project.id, accessible_project_2.id].join(',')
        projects = described_class.new(user, project_ids: project_ids).projects

        expect(projects).to match_array [accessible_project, accessible_project_2]
      end

      it 'returns the projects for guests' do
        search_project = create :project
        search_project.add_guest(user)
        project_ids = [accessible_project.id, accessible_project_2.id, search_project.id].join(',')
        projects = described_class.new(user, project_ids: project_ids).projects

        expect(projects).to match_array [accessible_project, accessible_project_2, search_project]
      end

      it 'handles spaces in the param' do
        project_ids = [accessible_project.id, accessible_project_2.id].join(',    ')
        projects = described_class.new(user, project_ids: project_ids).projects

        expect(projects).to match_array [accessible_project, accessible_project_2]
      end

      it 'returns nil if projects param is not a String' do
        project_ids = accessible_project.id
        projects = described_class.new(user, project_ids: project_ids).projects

        expect(projects).to be_nil
      end
    end

    context 'when some projects are accessible' do
      it 'returns only accessible projects' do
        project_ids = [accessible_project.id, inaccessible_project.id].join(',')
        projects = described_class.new(user, project_ids: project_ids).projects

        expect(projects).to match_array [accessible_project]
      end
    end

    context 'when no projects are accessible' do
      it 'returns nil' do
        project_ids = inaccessible_project.id.to_s
        projects = described_class.new(user, project_ids: project_ids).projects

        expect(projects).to be_nil
      end
    end

    context 'when no project_ids are provided' do
      it 'returns nil' do
        projects = described_class.new(user).projects

        expect(projects).to be_nil
      end
    end
  end

  describe '#use_elasticsearch?' do
    let_it_be(:user) { create(:user) }

    context 'when project is present' do
      let_it_be(:project) { create(:project, :public) }

      it 'Search::ProjectService receives use_elasticsearch?' do
        expect_next_instance_of(::Search::ProjectService) do |project_service|
          expect(project_service).to receive(:use_elasticsearch?).and_return 'result'
        end
        expect(described_class.new(user, project_ids: project.id.to_s).use_elasticsearch?).to eq 'result'
      end
    end

    context 'when project is not present' do
      it 'Search::GlobalService receives use_elasticsearch?' do
        expect_next_instance_of(::Search::GlobalService) do |global_service|
          expect(global_service).to receive(:use_elasticsearch?).and_return 'result'
        end
        expect(described_class.new(user).use_elasticsearch?).to eq 'result'
      end
    end
  end

  describe '.global_search_enabled_for_scope?' do
    using RSpec::Parameterized::TableSyntax
    let_it_be(:user) { create(:user) }
    let(:search_service) { described_class.new(user, { scope: scope, search: search }) }
    let(:search) { 'foobar' }

    where(:scope, :admin_setting, :setting_enabled, :expected) do
      'blobs'          | :global_search_code_enabled           | false | false
      'blobs'          | :global_search_code_enabled           | true  | true
      'commits'        | :global_search_commits_enabled        | false | false
      'commits'        | :global_search_commits_enabled        | true  | true
      'epics'          | :global_search_epics_enabled          | false | false
      'epics'          | :global_search_epics_enabled          | true  | true
      'wiki_blobs'     | :global_search_wiki_enabled           | false | false
      'wiki_blobs'     | :global_search_wiki_enabled           | true  | true
    end

    with_them do
      it 'returns false when feature_flag is not enabled and returns true when feature_flag is enabled' do
        stub_application_setting(admin_setting => setting_enabled)
        expect(search_service.global_search_enabled_for_scope?).to eq expected
      end
    end
  end

  describe '#search_type' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:group) { create(:group, :public) }
    let(:scope) { 'notes' }
    let(:expected_search_type) { 'advanced' }

    subject(:search_type) { service.search_type }

    context 'for project search' do
      let(:service) { described_class.new(user, { scope: scope, project_id: project.id }) }

      it 'delegates to ProjectService.search_type' do
        expect_next_instance_of(::Search::ProjectService) do |project_service|
          expect(project_service).to receive(:search_type).and_return(expected_search_type)
        end

        expect(search_type).to eq(expected_search_type)
      end
    end

    context 'for group search' do
      let(:service) { described_class.new(user, { scope: scope, group_id: group.id }) }

      it 'delegates to GroupService.search_type' do
        expect_next_instance_of(::Search::GroupService) do |group_service|
          expect(group_service).to receive(:search_type).and_return(expected_search_type)
        end

        expect(search_type).to eq(expected_search_type)
      end
    end

    context 'for global search' do
      let(:service) { described_class.new(user, { scope: scope }) }

      it 'delegates to GlobalService.search_type' do
        expect_next_instance_of(::Search::GlobalService) do |global_service|
          expect(global_service).to receive(:search_type).and_return(expected_search_type)
        end

        expect(search_type).to eq(expected_search_type)
      end
    end
  end

  describe '#search_type_errors' do
    let_it_be(:user) { create(:user) }
    let(:search_service) { described_class.new(user, { scope: scope, search_type: search_type }) }
    let(:scope) { 'blobs' }

    before do
      allow(search_service).to receive(:scope).and_return(scope)
    end

    context 'when search_type is basic' do
      let(:search_type) { 'basic' }

      it 'is nil' do
        expect(search_service.search_type_errors).to be_nil
      end
    end

    context 'when search_type is advanced' do
      let(:search_type) { 'advanced' }

      it 'is nil if use_elasticsearch?' do
        allow(search_service).to receive(:use_elasticsearch?).and_return(true)

        expect(search_service.search_type_errors).to be_nil
      end

      it 'returns an error if not use_elasticsearch?' do
        allow(search_service).to receive(:use_elasticsearch?).and_return(false)

        expect(search_service.search_type_errors).to eq('Elasticsearch is not available')
      end
    end

    context 'when search_type is zoekt' do
      let(:search_type) { 'zoekt' }

      it 'is nil if use_zoekt?' do
        allow(search_service).to receive(:use_zoekt?).and_return(true)

        expect(search_service.search_type_errors).to be_nil
      end

      it 'returns an error if not use_zoekt?' do
        allow(search_service).to receive(:use_zoekt?).and_return(false)

        expect(search_service.search_type_errors).to eq('Zoekt is not available')
      end

      it 'returns an error if scope is not blobs' do
        allow(search_service).to receive(:use_zoekt?).and_return(true)
        allow(search_service).to receive(:scope).and_return('issues')

        expect(search_service.search_type_errors).to eq('Zoekt can only be used for blobs')
      end
    end
  end
end
