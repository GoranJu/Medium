<script>
import { compact } from 'lodash';
import { GlAvatar, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';
import dateFormat, { masks } from '~/lib/dateformat';
import {
  BACKGROUND_AGGREGATION_DOCS_LINK,
  BACKGROUND_AGGREGATION_WARNING_TITLE,
  ENABLE_BACKGROUND_AGGREGATION_WARNING_TEXT,
} from 'ee/analytics/dashboards/constants';
import SingleStat from './single_stat.vue';

export default {
  name: 'UsageOverview',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAvatar,
    GlIcon,
    SingleStat,
  },
  inject: {
    overviewCountsAggregationEnabled: {
      type: Boolean,
    },
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    recordedAt() {
      const allRecordedAt = compact(this.data.metrics.map((metric) => metric.recordedAt));
      const [mostRecentRecordedAt] = allRecordedAt.sort().slice(-1);

      if (!mostRecentRecordedAt) return null;

      return dateFormat(mostRecentRecordedAt, `${masks.isoDate} ${masks.shortTime}`);
    },
    avatarAltText() {
      const { fullName } = this.data.namespace;
      return sprintf(__("%{name}'s avatar"), { name: fullName });
    },
  },
  mounted() {
    const { recordedAt } = this;
    const { tooltip, lastUpdated } = this.$options.i18n;
    const tooltipText = `${tooltip}${recordedAt ? sprintf(lastUpdated, { recordedAt }) : ''}`;
    this.$emit('showTooltip', { description: tooltipText });

    if (!this.overviewCountsAggregationEnabled) {
      const { description, descriptionLink, backgroundAggregationNoData } = this.$options.i18n;
      this.$emit('set-alerts', {
        title: this.$options.i18n.backgroundAggregationWarningTitle,
        description: backgroundAggregationNoData,
        warnings: [{ description, link: descriptionLink }],
        canRetry: false,
      });
    }
  },
  methods: {
    displayValue(value) {
      if (value > 0) return value;
      return this.overviewCountsAggregationEnabled ? 0 : '-';
    },
  },
  i18n: {
    tooltip: s__(
      'Analytics|Statistics on namespace usage. Usage data is a cumulative count, and updated monthly.',
    ),
    lastUpdated: s__('Analytics| Last updated: %{recordedAt}'),
    backgroundAggregationWarningTitle: BACKGROUND_AGGREGATION_WARNING_TITLE,
    description: ENABLE_BACKGROUND_AGGREGATION_WARNING_TEXT,
    descriptionLink: BACKGROUND_AGGREGATION_DOCS_LINK,
    backgroundAggregationNoData: __('No data available'),
  },
};
</script>
<template>
  <div class="gl-font-size-sm gl-flex gl-flex-row">
    <div
      v-if="data.namespace"
      data-testid="usage-overview-namespace"
      class="gl-flex gl-items-center gl-gap-3 gl-pr-9"
    >
      <gl-avatar
        shape="rect"
        :src="data.namespace.avatarUrl"
        :size="48"
        :entity-name="data.namespace.fullName"
        :entity-id="data.namespace.id"
        :fallback-on-error="true"
        :alt="avatarAltText"
      />

      <div class="gl-leading-20">
        <span class="gl-mb-1 gl-block gl-text-base gl-font-normal gl-text-subtle">{{
          data.namespace.namespaceType
        }}</span>
        <div class="gl-flex gl-items-center gl-gap-2">
          <span class="gl-truncate-end gl-text-size-h2 gl-font-bold gl-text-strong">{{
            data.namespace.fullName
          }}</span>
          <gl-icon
            v-gl-tooltip.viewport
            variant="subtle"
            :name="data.namespace.visibilityLevelIcon"
            :title="data.namespace.visibilityLevelTooltip"
          />
        </div>
      </div>
    </div>

    <div
      v-for="metric in data.metrics"
      :key="metric.identifier"
      class="gl-pr-9"
      :data-testid="`usage-overview-metric-${metric.identifier}`"
    >
      <single-stat :data="displayValue(metric.value)" :options="metric.options" />
    </div>
  </div>
</template>
