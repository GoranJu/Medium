# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::Visualization, feature_category: :product_analytics do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project, reload: true) do
    create(:project, :with_product_analytics_dashboard, group: group,
      project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
    )
  end

  let_it_be(:user) { create(:user) }

  let(:dashboards) { project.product_analytics_dashboards(user) }
  let(:num_builtin_visualizations) { 14 }
  let(:num_custom_visualizations) { 2 }
  let(:project_vsd_available_visualizations) do
    %w[
      dora_chart
      usage_overview
      change_failure_rate_over_time
      deployment_frequency_over_time
      lead_time_for_changes_over_time
      time_to_restore_service_over_time
      vsd_dora_metrics_table
      vsd_lifecycle_metrics_table
      vsd_security_metrics_table
    ]
  end

  let(:group_only_visualizations) { %w[dora_performers_score dora_projects_comparison] }
  let(:group_vsd_available_visualizations) do
    [].concat(group_only_visualizations, project_vsd_available_visualizations)
  end

  let(:ai_impact_available_visualizations) do
    %w[
      ai_impact_table
      ai_impact_lifecycle_metrics_table
      ai_impact_ai_metrics_table
      code_suggestions_usage_rate_over_time
      code_suggestions_acceptance_rate_over_time
      duo_chat_usage_rate_over_time
      duo_usage_rate_over_time
    ]
  end

  before do
    allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
    stub_licensed_features(
      product_analytics: true,
      project_level_analytics_dashboard: true,
      group_level_analytics_dashboard: true
    )
    project.project_setting.update!(product_analytics_instrumentation_key: "key")
    allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
      allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
        'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
      }))
    end
  end

  shared_examples_for 'a valid visualization' do
    it 'returns a valid visualization' do
      expect(dashboard.panels.first.visualization).to be_a(described_class)
    end
  end

  shared_examples_for 'shows AI impact visualizations when available' do
    before do
      allow(Ability).to receive(:allowed?)
                    .with(user, :read_enterprise_ai_analytics, anything)
                    .and_return(true)
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
    end

    it 'includes built in visualizations for AI impact dashboard' do
      expect(subject.map(&:slug)).to include(*ai_impact_available_visualizations)
    end
  end

  describe '#slug' do
    subject { described_class.for(container: project, user: user) }

    it 'returns the slugs' do
      expect(subject.map(&:slug)).to include('cube_bar_chart', 'cube_line_chart')
    end
  end

  describe '#schema_errors_for' do
    let(:dashboard) { dashboards.find { |d| d.title == 'Audience' } }

    it 'fetches correct schema path' do
      allow(JSONSchemer).to receive(:schema).and_call_original
      expect(JSONSchemer).to receive(:schema).with(Rails.root.join(described_class::SCHEMA_PATH))

      dashboard.panels.first.visualization
    end
  end

  describe '.for' do
    context 'when resource_parent is a Project' do
      subject { described_class.for(container: project, user: user) }

      it 'returns all visualizations stored in the project as well as built-in ones' do
        available_visualizations_count = num_builtin_visualizations +
          num_custom_visualizations + project_vsd_available_visualizations.length

        expect(subject.count).to eq(available_visualizations_count)
        expect(subject.map { |v| v.config['type'] }).to include('BarChart', 'LineChart')
      end

      it 'returns the available project vsd visualizations' do
        expect(subject.map(&:slug)).to include(*project_vsd_available_visualizations)

        expect(subject.map(&:slug)).not_to include(*group_only_visualizations)
      end

      context 'when a custom dashboard pointer project is configured' do
        let_it_be(:pointer_project) do
          create(:project, :with_product_analytics_custom_visualization, namespace: project.namespace)
        end

        before do
          project.update!(analytics_dashboards_configuration_project: pointer_project)
        end

        it 'returns custom visualizations from pointer project' do
          # :with_product_analytics_custom_visualization adds another visualization
          expected_visualizations_count = num_builtin_visualizations + 1 + project_vsd_available_visualizations.length

          expect(subject.count).to eq(expected_visualizations_count)
          expect(subject.map(&:slug)).to include('example_custom_visualization')
        end

        it 'does not return custom visualizations from self' do
          expect(subject.map { |v| v.config['title'] }).not_to include('Daily Something', 'Example title')
        end
      end

      context 'when the product analytics feature is disabled' do
        before do
          stub_licensed_features(product_analytics: false)
        end

        it 'returns all visualizations stored in the project but no built in product analytics visualizations' do
          expect(subject.count).to eq(num_custom_visualizations)
          expect(subject.map { |v| v.config['type'] }).to include('BarChart', 'LineChart')
        end
      end

      context 'when the product analytics feature is not onboarded' do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: nil)
        end

        it 'returns all visualizations stored in the project but no built in product analytics visualizations' do
          available_visualizations_count = num_custom_visualizations + project_vsd_available_visualizations.length

          expect(subject.count).to eq(available_visualizations_count)
          expect(subject.map { |v| v.config['type'] }).to include('BarChart', 'LineChart')
        end
      end

      it_behaves_like 'shows AI impact visualizations when available'
    end

    context 'when resource_parent is a group' do
      let_it_be_with_reload(:group) { create(:group) }

      subject { described_class.for(container: group, user: user) }

      it 'returns built in visualizations' do
        expect(subject.map(&:slug)).to match_array(group_vsd_available_visualizations)
      end

      it 'returns the group only visualizations' do
        expect(subject.map(&:slug)).to include(*group_only_visualizations)
      end

      context 'when group value stream dashboard is not available' do
        before do
          stub_licensed_features(group_level_analytics_dashboard: false)
        end

        it 'does not include built in visualizations for VSD' do
          expect(subject.map(&:slug)).to be_empty
        end
      end

      context 'when the VSD dashboard editor feature is disabled' do
        before do
          stub_feature_flags(vsd_visualizations_in_analytics_dashboard_editor: false)
        end

        it 'does not include built in visualizations for VSD' do
          expect(subject.map(&:slug)).not_to match_array(group_vsd_available_visualizations)
        end
      end

      context 'when a custom configuration project is defined' do
        let_it_be(:config_project) { create(:project, :with_product_analytics_custom_visualization, group: group) }

        before do
          group.update!(analytics_dashboards_configuration_project: config_project)
        end

        it 'returns builtin and custom visualizations' do
          expected_visualizations = [].concat(['example_custom_visualization'], group_vsd_available_visualizations)

          expect(subject.map(&:slug)).to match_array(expected_visualizations)
        end
      end

      it_behaves_like 'shows AI impact visualizations when available'
    end
  end

  describe '.from_file' do
    where(:filename) do
      %w[
        average_session_duration
        average_sessions_per_user
        browsers_per_users
        daily_active_users
        events_over_time
        page_views_over_time
        returning_users_percentage
        sessions_over_time
        sessions_per_browser
        top_pages
        total_events
        total_pageviews
        total_sessions
        total_unique_users
        usage_overview
        dora_chart
        vsd_lifecycle_metrics_table
        vsd_dora_metrics_table
        vsd_security_metrics_table
        dora_performers_score
        dora_projects_comparison
        deployment_frequency_over_time
        lead_time_for_changes_over_time
        time_to_restore_service_over_time
        change_failure_rate_over_time
        ai_impact_table
        ai_impact_lifecycle_metrics_table
        ai_impact_ai_metrics_table
        pushes
        merge_requests
        issues
        contributions_by_user
      ]
    end

    with_them do
      it 'returns the correct visualization path' do
        visualization = described_class.from_file(filename: filename, project: project)

        expect(visualization.type).to be_present
        expect(visualization.slug).to eq(filename)
        expect(visualization.errors).to be_nil
      end
    end

    context 'when file cannot be opened' do
      it 'initializes visualization with errors' do
        visualization = described_class.from_file(filename: 'not-existing-file', project: project)

        expect(visualization.slug).to eq('not-existing-file')
        expect(visualization.errors).to match_array(['Visualization file not-existing-file.yaml not found'])
      end
    end
  end

  describe '.product_analytics_visualizations' do
    subject { described_class.product_analytics_visualizations }

    num_builtin_visualizations = 14

    it 'returns the product analytics builtin visualizations' do
      expect(subject.count).to eq(num_builtin_visualizations)
    end
  end

  describe '.value_stream_dashboard_visualizations' do
    subject { described_class.value_stream_dashboard_visualizations }

    num_builtin_visualizations = 11

    it 'returns the value stream dashboard builtin visualizations' do
      expect(subject.count).to eq(num_builtin_visualizations)
    end
  end

  context 'when dashboard is a built-in dashboard' do
    let(:dashboard) { dashboards.find { |d| d.title == 'Audience' } }

    it_behaves_like 'a valid visualization'
  end

  context 'when dashboard is a local dashboard' do
    let(:dashboard) { dashboards.find { |d| d.title == 'Dashboard Example 1' } }

    it_behaves_like 'a valid visualization'
  end

  context 'when visualization is data not a file' do
    let_it_be(:project) do
      create(:project, :with_product_analytics_dashboard_with_inline_visualization, group: group,
        project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
      )
    end

    let(:dashboard) { dashboards.find { |d| d.title == 'Dashboard Example Inline Vis' } }

    it_behaves_like 'a valid visualization'
  end

  context 'when the inline visualization does not contain a slug' do
    let_it_be(:project) do
      create(:project, :with_product_analytics_dashboard_with_inline_visualization_no_slug, group: group,
        project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
      )
    end

    let(:dashboard) { dashboards.find { |d| d.title == 'Dashboard Example Inline Vis No Slug' } }

    it_behaves_like 'a valid visualization'

    it 'contains a randomly generated slug' do
      expect(dashboard.panels.first.visualization.slug).to be_a(String)
    end
  end

  context 'when visualization is loaded with attempted path traversal' do
    let_it_be(:project) do
      create(:project, :with_dashboard_attempting_path_traversal, group: group,
        project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
      )
    end

    let(:dashboard) { dashboards.find { |d| d.title == 'Dashboard Example 1' } }

    it 'raises an error' do
      expect { dashboard.panels.first.visualization }.to raise_error(Gitlab::PathTraversal::PathTraversalAttackError)
    end
  end

  context 'when visualization definition is invalid' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) do
      create(:project, :with_product_analytics_invalid_custom_visualization, group: group,
        project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
      )
    end

    subject { described_class.for(container: project, user: user) }

    it 'captures the error' do
      vis = (subject.select { |v| v.slug == 'example_invalid_custom_visualization' }).first
      expected = ["property '/type' is not one of: " \
                  "[\"LineChart\", \"ColumnChart\", \"DataTable\", \"SingleStat\", " \
                  "\"DORAChart\", \"UsageOverview\", \"DoraPerformersScore\", \"DoraProjectsComparison\", " \
                  "\"AiImpactTable\", \"ContributionsByUserTable\", \"ContributionsPushesChart\", " \
                  "\"ContributionsIssuesChart\", \"ContributionsMergeRequestsChart\"]"]
      expect(vis&.errors).to match_array(expected)
    end
  end

  context 'when the visualization has syntax errors' do
    let_it_be(:invalid_yaml) do
      <<-YAML
---
invalid yaml here not good
other: okay1111
      YAML
    end

    subject { described_class.new(config: invalid_yaml, slug: 'test') }

    it 'captures the syntax error' do
      expect(subject.errors).to match_array(['root is not of type: object'])
    end
  end

  context 'when initialized with init_error' do
    subject do
      described_class.new(config: nil, slug: "not-existing",
        init_error: "Some init error")
    end

    it 'captures the init_error' do
      expect(subject.errors).to match_array(['Some init error'])
    end
  end

  describe 'handling slugs correctly' do
    subject do
      described_class.new(config: nil, slug: slug,
        init_error: "Some init error").slug
    end

    context 'when slug contains a hyphen' do
      let(:slug) { 'hello-world' }

      it { is_expected.to eq 'hello-world' }
    end

    context 'when slug contains a underscore' do
      let(:slug) { 'hello_world' }

      it { is_expected.to eq 'hello_world' }
    end
  end
end
