<script>
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters } from 'vuex';
import { __ } from '~/locale';
import { getDurationChart } from 'ee/api/analytics_api';
import {
  getDurationOverviewChartData,
  getDurationChartData,
  checkForDataError,
  alertErrorIfStatusNotOk,
} from '../../utils';
import OverviewChart from './overview_chart.vue';
import StageChart from './stage_chart.vue';

export default {
  name: 'DurationChartLoader',
  components: {
    OverviewChart,
    StageChart,
  },
  data() {
    return {
      isLoading: false,
      durationData: [],
      errorMessage: '',
    };
  },
  computed: {
    ...mapState(['selectedStage', 'createdAfter', 'createdBefore']),
    ...mapGetters([
      'isOverviewStageSelected',
      'activeStages',
      'cycleAnalyticsRequestParams',
      'namespaceRestApiRequestPath',
      'currentValueStreamId',
    ]),
    hasPlottableData() {
      return this.durationData.some(({ data }) => data.length);
    },
    overviewChartPlottableData() {
      return this.hasPlottableData ? getDurationOverviewChartData(this.durationData) : [];
    },
    stageChartPlottableData() {
      const { createdAfter, createdBefore, durationData, selectedStage } = this;
      const stageDurationData = durationData.find((stage) => stage.id === selectedStage.id);

      return stageDurationData?.data?.length
        ? getDurationChartData([stageDurationData], createdAfter, createdBefore)
        : [];
    },
  },
  watch: {
    selectedStage() {
      this.fetchDurationData();
    },
  },
  created() {
    this.fetchDurationData();
  },
  methods: {
    fetchDurationData() {
      this.isLoading = true;
      this.errorMessage = '';

      Promise.all(
        this.activeStages.map(({ id, name }) => {
          return getDurationChart({
            stageId: id,
            namespacePath: this.namespaceRestApiRequestPath,
            valueStreamId: this.currentValueStreamId,
            params: this.cycleAnalyticsRequestParams,
          })
            .then(checkForDataError)
            .then(({ data }) => ({ id, name, selected: true, data }));
        }),
      )
        .then((data) => {
          this.durationData = data;
        })
        .catch((error) => {
          this.durationData = [];
          this.errorMessage = error.message;
          alertErrorIfStatusNotOk({
            error,
            message: __('There was an error while fetching value stream analytics duration data.'),
          });
        })
        .finally(() => {
          this.isLoading = false;
        });
    },
  },
};
</script>
<template>
  <overview-chart
    v-if="isOverviewStageSelected"
    :is-loading="isLoading"
    :error-message="errorMessage"
    :plottable-data="overviewChartPlottableData"
  />
  <stage-chart
    v-else
    :stage-title="selectedStage.title"
    :is-loading="isLoading"
    :error-message="errorMessage"
    :plottable-data="stageChartPlottableData"
  />
</template>
