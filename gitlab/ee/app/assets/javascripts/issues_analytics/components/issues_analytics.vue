<script>
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import {
  nMonthsBefore,
  getCurrentUtcDate,
  dateAtFirstDayOfMonth,
} from '~/lib/utils/datetime_utility';
import { s__ } from '~/locale';
import { createAlert, VARIANT_WARNING } from '~/alert';
import FilteredSearchIssueAnalytics from '../filtered_search_issues_analytics';
import { RENAMED_FILTER_KEYS_CHART, DEFAULT_MONTHS_BACK } from '../constants';
import { transformFilters } from '../utils';
import IssuesAnalyticsTable from './issues_analytics_table.vue';
import IssuesAnalyticsChart from './issues_analytics_chart.vue';
import TotalIssuesAnalyticsChart from './total_issues_analytics_chart.vue';

export default {
  components: {
    IssuesAnalyticsTable,
    IssuesAnalyticsChart,
    TotalIssuesAnalyticsChart,
  },
  inject: {
    hasIssuesCompletedFeature: {
      default: false,
    },
  },
  props: {
    filterBlockEl: {
      type: HTMLDivElement,
      required: true,
    },
  },
  computed: {
    ...mapGetters('issueAnalytics', ['appliedFilters']),
    supportsIssuesCompletedAnalytics() {
      return this.hasIssuesCompletedFeature;
    },
    monthsBack() {
      const { months_back: monthsBack } = this.appliedFilters ?? {};

      return monthsBack ?? DEFAULT_MONTHS_BACK;
    },
    startDate() {
      const monthsBeforeDate = nMonthsBefore(this.endDate, Number(this.monthsBack), { utc: true });

      return dateAtFirstDayOfMonth(monthsBeforeDate, { utc: true });
    },
    endDate() {
      return getCurrentUtcDate();
    },
    chartFilters() {
      return transformFilters(this.appliedFilters, RENAMED_FILTER_KEYS_CHART);
    },
    tableFilters() {
      return transformFilters(this.appliedFilters);
    },
  },
  watch: {
    appliedFilters: {
      handler(filters) {
        if (filters?.search) {
          createAlert({
            message: this.$options.i18n.rawTextSearchWarning,
            variant: VARIANT_WARNING,
          });
        }
      },
      immediate: true,
    },
  },
  created() {
    const { hasIssuesCompletedFeature } = this;

    this.filterManager = new FilteredSearchIssueAnalytics({
      hasIssuesCompletedFeature,
      ...this.appliedFilters,
    });
    this.filterManager.setup();
  },
  methods: {
    hideFilteredSearchBar() {
      this.filterBlockEl.classList.add('hide');
    },
  },
  i18n: {
    rawTextSearchWarning: s__(
      'IssuesAnalytics|Raw text search is not supported. Please use the available filters.',
    ),
  },
};
</script>
<template>
  <div class="issues-analytics-wrapper">
    <div class="gl-mt-6" data-testid="issues-analytics-chart-wrapper">
      <total-issues-analytics-chart
        v-if="supportsIssuesCompletedAnalytics"
        data-testid="issues-analytics-graph"
        :start-date="startDate"
        :end-date="endDate"
        :filters="chartFilters"
        @hideFilteredSearchBar="hideFilteredSearchBar"
      />
      <issues-analytics-chart
        v-else
        data-testid="issues-analytics-graph"
        @hasNoData="hideFilteredSearchBar"
      />
    </div>
    <issues-analytics-table
      :start-date="startDate"
      :end-date="endDate"
      :filters="tableFilters"
      :has-completed-issues="supportsIssuesCompletedAnalytics"
      class="gl-mt-6"
    />
  </div>
</template>
