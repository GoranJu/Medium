<script>
import { GlSingleStat } from '@gitlab/ui/dist/charts';
import { humanizeDisplayUnit, calculateDecimalPlaces } from './utils';

export default {
  name: 'SingleStat',
  components: {
    GlSingleStat,
  },
  props: {
    data: {
      type: [String, Number],
      required: false,
      default: 0,
    },
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    title() {
      return this.options.title ?? '';
    },
    decimalPlaces() {
      // Only set the decimals places if this has data
      const {
        data,
        options: { decimalPlaces },
      } = this;
      return calculateDecimalPlaces({ data, decimalPlaces });
    },
    humanizedUnit() {
      const {
        data,
        options: { unit },
      } = this;
      return humanizeDisplayUnit({ data, unit });
    },
  },
  mounted() {
    const { tooltip } = this.options;

    if (tooltip) {
      this.$emit('showTooltip', tooltip);
    }
  },
};
</script>

<template>
  <div class="gl-flex gl-h-full gl-items-center">
    <gl-single-stat
      class="!gl-p-0"
      :value="data"
      :title="title"
      :meta-text="options.metaText"
      :meta-icon="options.metaIcon"
      :title-icon="options.titleIcon"
      :unit="humanizedUnit"
      :animation-decimal-places="decimalPlaces"
      :should-animate="true"
      :use-delimiters="true"
      variant="muted"
    />
  </div>
</template>
