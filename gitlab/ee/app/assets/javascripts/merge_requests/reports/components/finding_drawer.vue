<script>
import { GlDrawer } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';

export default {
  components: {
    GlDrawer,
  },
  props: {
    open: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    getDrawerHeaderHeight() {
      if (!this.open) return '0';
      return getContentWrapperHeight();
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    :open="open"
    @close="$emit('close')"
  >
    <template #title>
      <h4 class="gl-my-0">{{ __('Violates security policy') }}</h4>
    </template>
  </gl-drawer>
</template>
