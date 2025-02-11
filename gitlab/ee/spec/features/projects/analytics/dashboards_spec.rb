# frozen_string_literal: true

require 'spec_helper'
require_relative '../product_analytics/dashboards_shared_examples'

RSpec.describe 'Analytics Dashboard - Product Analytics', :js, feature_category: :product_analytics do
  let_it_be(:current_user) { create(:user, :with_namespace) }
  let_it_be(:user) { current_user }
  let_it_be(:group) { create(:group, :with_organization) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }

  before do
    sign_in(user)
    project.reload
  end

  subject(:visit_page) { visit project_analytics_dashboards_path(project) }

  it_behaves_like 'product analytics dashboards' do
    let(:project_settings) { { product_analytics_instrumentation_key: 456 } }
    let(:application_settings) do
      {
        product_analytics_configurator_connection_string: 'https://configurator.example.com',
        product_analytics_data_collector_host: 'https://collector.example.com',
        cube_api_base_url: 'https://cube.example.com',
        cube_api_key: '123'
      }
    end
  end
end

RSpec.describe 'Analytics Dashboard - Value Streams Dashboard', :js, feature_category: :value_stream_management do
  include ValueStreamsDashboardHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:user) { current_user }
  let_it_be(:group) { create(:group, :with_organization, name: "vsd test group") }
  let_it_be(:project) { create(:project, :repository, name: "vsd project", namespace: group) }

  let(:metric_table) { find_by_testid('panel-dora-chart') }

  it 'renders a 404 error for a user without permission' do
    sign_in(user)
    visit_project_analytics_dashboards_list(project)

    expect(page).to have_content _("Page not found")
  end

  context 'with a valid user' do
    before_all do
      group.add_developer(user)
      project.add_developer(user)
    end

    context 'with combined_project_analytics_dashboards and project_level_analytics_dashboard license' do
      let_it_be(:environment) { create(:environment, :production, project: project) }

      before do
        stub_licensed_features(
          combined_project_analytics_dashboards: true, project_level_analytics_dashboard: true,
          dora4_analytics: true, security_dashboard: true, cycle_analytics_for_projects: true,
          group_level_analytics_dashboard: true, cycle_analytics_for_groups: true
        )

        sign_in(user)
      end

      context 'for dashboard listing' do
        before do
          visit_project_analytics_dashboards_list(project)
        end

        it 'renders the dashboard list correctly' do
          expect(page).to have_content _('Analytics dashboards')
          expect(page).to have_content _('Dashboards are created by editing the projects dashboard files')
        end

        it_behaves_like 'has value streams dashboard link'
      end

      context 'for Value streams dashboard' do
        context 'with default configuration' do
          before do
            visit_project_value_streams_dashboard(project)
          end

          it_behaves_like 'VSD renders as an analytics dashboard'

          it_behaves_like 'does not render contributor count'

          it 'does not render dora performers score panel' do
            # Currently does not support project namespaces
            expect(page).not_to have_selector("[data-testid='panel-dora-performers-score']")
          end
        end

        context 'with usage overview background aggregation enabled' do
          before do
            create(:value_stream_dashboard_aggregation, namespace: group, enabled: true)

            visit_project_value_streams_dashboard(project)
          end

          it_behaves_like 'does not render usage overview background aggregation not enabled alert'
        end

        context 'for comparison table' do
          before_all do
            create_mock_dora_chart_metrics(environment)
          end

          before do
            Analytics::CycleAnalytics::DataLoaderService.new(namespace: group, model: Issue).execute
            visit_project_value_streams_dashboard(project)
          end

          it_behaves_like 'renders metrics comparison tables' do
            let(:panel_title) { "#{project.name} project" }
          end
        end

        context 'for usage overview panel' do
          context 'when background aggregation is disabled' do
            context 'with data' do
              before do
                create_mock_usage_overview_metrics(project)

                visit_project_value_streams_dashboard(project)
              end

              it_behaves_like 'renders usage overview metrics' do
                let(:panel_title) { "#{project.name} project" }
                let(:usage_overview_metrics) { expected_usage_overview_metrics(is_project: true) }
              end
            end

            context 'without data' do
              before do
                visit_project_value_streams_dashboard(project)
              end

              it_behaves_like 'renders usage overview metrics with empty values' do
                let(:panel_title) { "#{project.name} project" }
                let(:usage_overview_metrics) { expected_usage_overview_metrics_empty_values(is_project: true) }
              end
            end
          end

          context 'when background aggregation is enabled' do
            before do
              create(:value_stream_dashboard_aggregation, namespace: group, enabled: true)
            end

            context 'with data' do
              before do
                create_mock_usage_overview_metrics(project)

                visit_project_value_streams_dashboard(project)
              end

              it_behaves_like 'renders usage overview metrics' do
                let(:panel_title) { "#{project.name} project" }
                let(:usage_overview_metrics) { expected_usage_overview_metrics(is_project: true) }
              end
            end

            context 'without data' do
              before do
                visit_project_value_streams_dashboard(project)
              end

              it_behaves_like 'renders usage overview metrics with zero values' do
                let(:panel_title) { "#{project.name} project" }
                let(:usage_overview_metrics) { expected_usage_overview_metrics_zero_values(is_project: true) }
              end
            end
          end
        end
      end
    end
  end
end
