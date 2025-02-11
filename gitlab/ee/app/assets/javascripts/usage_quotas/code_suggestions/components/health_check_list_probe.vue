<script>
import { GlIcon } from '@gitlab/ui';

export default {
  name: 'HealthCheckListProbe',
  components: {
    GlIcon,
  },
  props: {
    probe: {
      type: Object,
      required: true,
    },
  },
  computed: {
    probeCSS() {
      return this.probe.success
        ? 'gl-text-green-900 gl-bg-green-50'
        : 'gl-text-red-900 gl-bg-red-50';
    },
    probeIcon() {
      return this.probe.success
        ? { name: 'check-circle', variant: 'success' }
        : { name: 'error', variant: 'danger' };
    },
  },
};
</script>

<template>
  <div
    class="gl-my-3 gl-rounded-small gl-px-3 gl-py-2"
    :class="probeCSS"
    data-testid="health-check-probe"
  >
    <gl-icon v-bind="probeIcon" />
    {{ probe.message }}
  </div>
</template>
