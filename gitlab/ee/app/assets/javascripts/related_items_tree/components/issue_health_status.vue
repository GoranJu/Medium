<script>
import { GlBadge, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import {
  healthStatusTextMap,
  healthStatusVariantMap,
  healthStatusIconMap,
  healthStatusColorMap,
} from 'ee/sidebar/constants';

export default {
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlBadge,
    GlIcon,
  },
  props: {
    healthStatus: {
      type: String,
      required: true,
      validator: (value) => Object.keys(healthStatusTextMap).includes(value),
    },
    displayAsText: {
      type: Boolean,
      required: false,
    },
    textSize: {
      type: String,
      required: false,
      default: 'base',
      validator: (value) => ['base', 'sm'].includes(value),
    },
    disableTooltip: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    statusText() {
      return healthStatusTextMap[this.healthStatus];
    },
    statusClass() {
      return healthStatusVariantMap[this.healthStatus];
    },
    statusIcon() {
      return healthStatusIconMap[this.healthStatus];
    },
    statusColor() {
      return healthStatusColorMap[this.healthStatus];
    },
    textSizeClass() {
      switch (this.textSize) {
        case 'sm':
          return 'gl-text-sm';
        case 'base':
        default:
          return 'gl-text-base';
      }
    },
  },
};
</script>

<template>
  <span
    v-if="displayAsText"
    v-gl-tooltip="{ disabled: disableTooltip }"
    data-testid="status-text"
    :title="__('Health status')"
    class="gl-inline-flex gl-items-center"
    :class="[statusColor, textSizeClass, !disableTooltip ? 'gl-cursor-help' : undefined]"
    ><gl-icon class="gl-mr-2" :size="16" :name="statusIcon" />{{ statusText }}</span
  >
  <gl-badge
    v-else
    v-gl-tooltip
    class="gl-font-bold"
    :title="__('Health status')"
    :variant="statusClass"
  >
    {{ statusText }}
  </gl-badge>
</template>
