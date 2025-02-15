<script>
import { GlLoadingIcon, GlTab, GlTabs } from '@gitlab/ui';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import {
  CI_CD_MINUTES_USAGE,
  SHARED_RUNNER_USAGE,
  SHARED_RUNNER_POPOVER_OPTIONS,
} from '../constants';
import { groupUsageDataByYear } from '../utils';
import MinutesUsagePerMonthChart from './minutes_usage_per_month_chart.vue';
import SharedRunnerUsageMonthChart from './shared_runner_usage_month_chart.vue';
import NoMinutesAlert from './no_minutes_alert.vue';

export default {
  name: 'MinutesUsagePerMonth',
  components: {
    MinutesUsagePerMonthChart,
    SharedRunnerUsageMonthChart,
    NoMinutesAlert,
    HelpPopover,
    GlLoadingIcon,
    GlTab,
    GlTabs,
  },
  props: {
    ciMinutesUsage: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedYear: {
      type: Number,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    usageDataByYear() {
      return groupUsageDataByYear(this.ciMinutesUsage);
    },
    hasCiMinutes() {
      return this.ciMinutesUsage.some((usage) => usage.minutes > 0);
    },
    hasSharedRunnersMinutes() {
      return this.ciMinutesUsage.some((usage) => usage.sharedRunnersDuration > 0);
    },
  },
  CI_CD_MINUTES_USAGE,
  SHARED_RUNNER_USAGE,
  SHARED_RUNNER_POPOVER_OPTIONS,
};
</script>

<template>
  <gl-tabs>
    <gl-tab :title="$options.CI_CD_MINUTES_USAGE">
      <div
        v-if="isLoading"
        class="chart-placeholder-height gl-flex gl-items-center gl-justify-center"
      >
        <gl-loading-icon size="lg" data-testid="pipelines-minutes-chart-loading-indicator" />
      </div>

      <no-minutes-alert v-else-if="!hasCiMinutes" />
      <minutes-usage-per-month-chart
        v-else
        :selected-year="selectedYear"
        :usage-data-by-year="usageDataByYear"
        data-testid="minutes-by-namespace"
      />
    </gl-tab>
    <gl-tab>
      <template #title>
        <div id="shared-runner-message-popover-container" class="gl-flex">
          <span class="gl-mr-2">{{ $options.SHARED_RUNNER_USAGE }}</span>
          <help-popover :options="$options.SHARED_RUNNER_POPOVER_OPTIONS" />
        </div>
      </template>

      <div
        v-if="isLoading"
        class="chart-placeholder-height gl-flex gl-items-center gl-justify-center"
      >
        <gl-loading-icon size="lg" data-testid="pipelines-shared-runners-chart-loading-indicator" />
      </div>

      <no-minutes-alert v-else-if="!hasSharedRunnersMinutes" />
      <shared-runner-usage-month-chart
        v-else
        :selected-year="selectedYear"
        :usage-data-by-year="usageDataByYear"
        data-testid="shared-runner-by-namespace"
      />
    </gl-tab>
  </gl-tabs>
</template>

<style>
.chart-placeholder-height {
  height: calc(400px + 1rem);
}
</style>
