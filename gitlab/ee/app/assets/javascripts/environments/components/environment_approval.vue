<script>
import { GlButton, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  components: {
    GlButton,
  },
  directives: {
    GlTooltip,
  },
  props: {
    requiredApprovalCount: {
      type: Number,
      required: true,
    },
    deploymentWebPath: {
      type: String,
      required: true,
    },
    showText: {
      type: Boolean,
      required: false,
      default: true,
    },
    size: {
      type: String,
      required: false,
      default: 'medium',
      validator: (value) => ['small', 'medium'].includes(value),
    },
  },
  computed: {
    buttonTitle() {
      return this.showText ? '' : this.$options.i18n.button;
    },
    needsApproval() {
      return this.requiredApprovalCount > 0;
    },
  },
  i18n: {
    button: s__('DeploymentApproval|Approval options'),
  },
};
</script>
<template>
  <gl-button
    v-if="needsApproval"
    v-gl-tooltip
    :title="buttonTitle"
    :aria-label="buttonTitle"
    :href="deploymentWebPath"
    :size="size"
    icon="thumb-up"
  >
    <template v-if="showText">
      {{ $options.i18n.button }}
    </template>
  </gl-button>
</template>
