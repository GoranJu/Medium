<script>
import { GlButton } from '@gitlab/ui';

export default {
  name: 'EditorLayoutCollapseHeader',
  components: {
    GlButton,
  },
  props: {
    header: {
      type: String,
      required: false,
      default: '',
    },
    collapsed: {
      type: Boolean,
      required: false,
      default: false,
    },
    isRight: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasResetButton: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    iconName() {
      return this.collapsed ? 'chevron-double-lg-right' : 'chevron-double-lg-left';
    },
    iconNameRightName() {
      return this.collapsed ? 'chevron-double-lg-left' : 'chevron-double-lg-right';
    },
  },
};
</script>

<template>
  <div class="gl-gap-x gl-flex gl-items-center">
    <div class="gl-flex gl-flex-grow-2 gl-items-center gl-bg-strong gl-px-4 gl-py-3">
      <gl-button
        v-if="isRight"
        class="gl-mr-3 gl-hidden lg:gl-block"
        category="tertiary"
        size="small"
        :icon="iconNameRightName"
        @click="$emit('toggle', !collapsed)"
      />
      <div v-if="!collapsed">
        <h5 class="gl-m-0" data-testid="header">{{ header }}</h5>
      </div>
      <gl-button
        v-if="!isRight"
        class="gl-hidden lg:gl-block"
        :class="{ 'gl-ml-auto': !collapsed }"
        category="tertiary"
        size="small"
        :icon="iconName"
        @click="$emit('toggle', !collapsed)"
      />
    </div>
    <gl-button
      v-if="hasResetButton"
      data-testid="reset-button"
      class="security-policies-drag-thumbnail gl-ml-3 !gl-min-h-7 !gl-min-w-6 !gl-rounded-none !gl-border-0 !gl-bg-strong"
      icon="redo"
      size="small"
      @click="$emit('reset-size')"
    />
  </div>
</template>
