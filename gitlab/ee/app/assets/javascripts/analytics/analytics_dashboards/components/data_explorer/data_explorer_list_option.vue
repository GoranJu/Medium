<script>
import { GlButton } from '@gitlab/ui';

export default {
  name: 'DataExplorerListOption',
  components: {
    GlButton,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    icon: {
      type: String,
      required: false,
      default: 'details-block',
    },
  },
};
</script>

<template>
  <li>
    <gl-button category="tertiary" variant="confirm" :icon="icon" @click="$emit('click')">{{
      title
    }}</gl-button>
    <div class="gl-text-subtle">
      {{ description }}
    </div>
  </li>
</template>
