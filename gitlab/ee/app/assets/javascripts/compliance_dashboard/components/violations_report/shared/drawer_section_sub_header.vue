<script>
export default {
  props: {
    isEmpty: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>
<template>
  <p class="gl-text-subtle" :class="{ 'gl-mb-4': !isEmpty, 'gl-mb-0': isEmpty }">
    <slot></slot>
  </p>
</template>
