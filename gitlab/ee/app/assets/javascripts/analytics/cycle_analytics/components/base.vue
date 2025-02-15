<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import { GlEmptyState } from '@gitlab/ui';
import { refreshCurrentPage } from '~/lib/utils/url_utility';
import { VSA_METRICS_GROUPS, FLOW_METRICS_QUERY_TYPE } from '~/analytics/shared/constants';
import {
  generateValueStreamsDashboardLink,
  overviewMetricsRequestParams,
} from '~/analytics/shared/utils';
import ValueStreamMetrics from '~/analytics/shared/components/value_stream_metrics.vue';
import PathNavigation from '~/analytics/cycle_analytics/components/path_navigation.vue';
import StageTable from '~/analytics/cycle_analytics/components/stage_table.vue';
import ValueStreamFilters from '~/analytics/cycle_analytics/components/value_stream_filters.vue';
import { OVERVIEW_STAGE_ID } from '~/analytics/cycle_analytics/constants';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import DurationChartLoader from './duration_charts/duration_chart_loader.vue';
import TypeOfWorkChartsLoader from './type_of_work_charts_loader.vue';
import ValueStreamAggregationStatus from './value_stream_aggregation_status.vue';
import ValueStreamAggregatingWarning from './value_stream_aggregating_warning.vue';
import ValueStreamEmptyState from './value_stream_empty_state.vue';
import ValueStreamSelect from './value_stream_select.vue';

export default {
  name: 'CycleAnalytics',
  components: {
    PageHeading,
    DurationChartLoader,
    GlEmptyState,
    TypeOfWorkChartsLoader,
    StageTable,
    PathNavigation,
    ValueStreamAggregationStatus,
    ValueStreamAggregatingWarning,
    ValueStreamEmptyState,
    ValueStreamFilters,
    ValueStreamMetrics,
    ValueStreamSelect,
    UrlSync,
  },
  props: {
    emptyStateSvgPath: {
      type: String,
      required: true,
    },
    noDataSvgPath: {
      type: String,
      required: true,
    },
    noAccessSvgPath: {
      type: String,
      required: true,
    },
    enableTasksByTypeChart: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    ...mapState([
      'isLoading',
      'isLoadingStage',
      'selectedProjects',
      'selectedStage',
      'stages',
      'selectedStageEvents',
      'createdAfter',
      'createdBefore',
      'isLoadingValueStreams',
      'selectedStageError',
      'selectedValueStream',
      'pagination',
      'aggregation',
      'isCreatingAggregation',
      'groupPath',
      'features',
      'canEdit',
      'enableProjectsFilter',
      'enableCustomizableStages',
      'predefinedDateRange',
      'enableVsdLink',
      'namespace',
      'canReadCycleAnalytics',
    ]),
    ...mapGetters([
      'hasNoAccessError',
      'namespaceRestApiRequestPath',
      'activeStages',
      'selectedProjectIds',
      'cycleAnalyticsRequestParams',
      'pathNavigationData',
      'isOverviewStageSelected',
      'selectedStageCount',
      'hasValueStreams',
      'isProjectNamespace',
    ]),
    isWaitingForNextAggregation() {
      return Boolean(this.selectedValueStream && !this.aggregation.lastRunAt);
    },
    shouldRenderEmptyState() {
      return this.isLoadingValueStreams || (!this.isCreatingAggregation && !this.hasValueStreams);
    },
    shouldRenderAggregationWarning() {
      return this.isCreatingAggregation || this.isWaitingForNextAggregation;
    },
    shouldRenderStageTable() {
      return !this.isOverviewStageSelected && this.selectedStageEvents.length;
    },
    selectedStageReady() {
      return !this.hasNoAccessError && this.selectedStage;
    },
    shouldDisplayCreateMultipleValueStreams() {
      return Boolean(
        this.enableCustomizableStages &&
          !this.shouldRenderEmptyState &&
          !this.isLoadingValueStreams &&
          !this.isCreatingAggregation,
      );
    },
    hasDateRangeSet() {
      return this.createdAfter && this.createdBefore;
    },
    isAggregationStatusAvailable() {
      return this.aggregation.lastRunAt;
    },
    selectedValueStreamName() {
      return this.selectedValueStream?.name;
    },
    query() {
      const { project_ids, created_after, created_before } = this.cycleAnalyticsRequestParams;
      const paginationUrlParams = !this.isOverviewStageSelected
        ? {
            sort: this.pagination?.sort || null,
            direction: this.pagination?.direction || null,
            page: this.pagination?.page || null,
          }
        : {
            sort: null,
            direction: null,
            page: null,
          };

      return {
        value_stream_id: this.selectedValueStream?.id || null,
        project_ids,
        created_after,
        created_before,
        stage_id: (!this.isOverviewStageSelected && this.selectedStage?.id) || null, // the `overview` stage is always the default, so dont persist the id if its selected
        ...paginationUrlParams,
      };
    },
    stageCount() {
      return this.activeStages.length;
    },
    showDashboardsLink() {
      return this.enableVsdLink && Boolean(this.features?.groupLevelAnalyticsDashboard);
    },
    dashboardsPath() {
      return this.showDashboardsLink
        ? generateValueStreamsDashboardLink(this.namespace?.path, this.isProjectNamespace)
        : null;
    },
    isAllowed() {
      return this.canReadCycleAnalytics;
    },
    overviewRequestParams() {
      return overviewMetricsRequestParams(this.cycleAnalyticsRequestParams);
    },
  },
  methods: {
    ...mapActions([
      'fetchCycleAnalyticsData',
      'fetchStageData',
      'setSelectedProjects',
      'setSelectedStage',
      'setDefaultSelectedStage',
      'setDateRange',
      'setPredefinedDateRange',
      'updateStageTablePagination',
    ]),
    onProjectsSelect(projects) {
      this.setSelectedProjects(projects);
    },
    onStageSelect(stage) {
      if (stage.id === OVERVIEW_STAGE_ID) {
        this.setDefaultSelectedStage();
      } else {
        this.setSelectedStage(stage);
        this.updateStageTablePagination({ ...this.pagination, page: 1 });
      }
    },
    onSetDateRange({ startDate, endDate }) {
      this.setDateRange({
        createdAfter: new Date(startDate),
        createdBefore: new Date(endDate),
      });
    },
    onHandleUpdatePagination(data) {
      this.updateStageTablePagination(data);
    },
    onHandleReloadPage() {
      refreshCurrentPage();
    },
  },
  VSA_METRICS_GROUPS,
  aggregationPopoverOptions: {
    triggers: 'hover',
    placement: 'left',
  },
  FLOW_METRICS_QUERY_TYPE,
};
</script>
<template>
  <div>
    <value-stream-empty-state
      v-if="shouldRenderEmptyState"
      :is-loading="isLoadingValueStreams"
      :empty-state-svg-path="emptyStateSvgPath"
      :has-date-range-error="!hasDateRangeSet"
      :can-edit="canEdit"
    />
    <template v-else>
      <page-heading :heading="__('Value stream analytics')" />
      <div
        class="gl-mb-6 gl-flex gl-flex-col gl-justify-between gl-gap-3 sm:gl-flex-row sm:gl-items-center"
      >
        <value-stream-select v-if="shouldDisplayCreateMultipleValueStreams" :can-edit="canEdit" />
        <value-stream-aggregation-status v-if="isAggregationStatusAvailable" :data="aggregation" />
      </div>
      <value-stream-filters
        v-if="!shouldRenderAggregationWarning"
        class="gl-mb-6"
        :namespace-path="namespaceRestApiRequestPath"
        :group-path="groupPath"
        :selected-projects="selectedProjects"
        :start-date="createdAfter"
        :end-date="createdBefore"
        :has-project-filter="enableProjectsFilter"
        :predefined-date-range="predefinedDateRange"
        @selectProject="onProjectsSelect"
        @setDateRange="onSetDateRange"
        @setPredefinedDateRange="setPredefinedDateRange"
      />
      <path-navigation
        v-if="selectedStageReady"
        data-testid="vsa-path-navigation"
        class="gl-mt-4 gl-w-full"
        :loading="isLoading"
        :stages="pathNavigationData"
        :selected-stage="selectedStage"
        @selected="onStageSelect"
      />
      <value-stream-aggregating-warning
        v-if="shouldRenderAggregationWarning"
        class="gl-my-6"
        :value-stream-title="selectedValueStreamName"
        @reload="onHandleReloadPage"
      />
      <gl-empty-state
        v-else-if="hasNoAccessError"
        class="js-empty-state gl-mt-2"
        :title="__('You don’t have access to Value Stream Analytics for this group')"
        :svg-path="noAccessSvgPath"
        :svg-height="null"
        :description="
          __(
            'Only \'Reporter\' roles and above on tiers Premium and above can see Value Stream Analytics.',
          )
        "
      />
      <template v-else>
        <value-stream-metrics
          v-if="isOverviewStageSelected"
          :request-path="namespace.path"
          :request-params="overviewRequestParams"
          :group-by="$options.VSA_METRICS_GROUPS"
          :dashboards-path="dashboardsPath"
          :query-type="$options.FLOW_METRICS_QUERY_TYPE"
          :is-project-namespace="isProjectNamespace"
          :is-licensed="isAllowed"
        />
        <div :class="[isOverviewStageSelected ? 'gl-mt-2' : 'gl-mt-6']">
          <duration-chart-loader v-if="activeStages.length" class="gl-mb-6" />
          <type-of-work-charts-loader
            v-if="enableTasksByTypeChart"
            v-show="isOverviewStageSelected"
            class="gl-mb-6"
          />
        </div>
        <stage-table
          v-if="shouldRenderStageTable"
          :is-loading="isLoading || isLoadingStage"
          :stage-events="selectedStageEvents"
          :selected-stage="selectedStage"
          :stage-count="selectedStageCount"
          :empty-state-message="selectedStageError"
          :no-data-svg-path="noDataSvgPath"
          :pagination="pagination"
          include-project-name
          @handleUpdatePagination="onHandleUpdatePagination"
        />
        <url-sync v-if="selectedStageReady" :query="query" />
      </template>
    </template>
  </div>
</template>
