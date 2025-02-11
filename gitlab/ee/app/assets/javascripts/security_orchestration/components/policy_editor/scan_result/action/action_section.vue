<script>
import { GlButton } from '@gitlab/ui';
import { ACTION_AND_LABEL } from '../../constants';
import ApproverAction from './approver_action.vue';

export default {
  ACTION_AND_LABEL,
  name: 'ActionSection',
  components: {
    GlButton,
    ApproverAction,
  },
  props: {
    actionIndex: {
      type: Number,
      required: true,
    },
    errors: {
      type: Array,
      required: false,
      default: () => [],
    },
    initAction: {
      type: Object,
      required: true,
    },
    isWarnType: {
      type: Boolean,
      required: false,
      default: false,
    },
    existingApprovers: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isFirstAction() {
      return this.actionIndex === 0;
    },
  },
  methods: {
    remove() {
      this.$emit('remove');
    },
  },
};
</script>

<template>
  <div>
    <div
      v-if="!isFirstAction"
      class="gl-mb-4 gl-ml-5 gl-text-subtle"
      data-testid="action-and-label"
    >
      {{ $options.ACTION_AND_LABEL }}
    </div>

    <div class="gl-flex gl-w-full">
      <div class="gl-flex-1">
        <approver-action
          :action-index="actionIndex"
          :init-action="initAction"
          :is-warn-type="isWarnType"
          :errors="errors"
          :existing-approvers="existingApprovers"
          @error="$emit('error')"
          @updateApprovers="$emit('updateApprovers', $event)"
          @changed="$emit('changed', $event)"
        />
      </div>
      <div class="security-policies-bg-subtle">
        <gl-button
          icon="remove"
          category="tertiary"
          :aria-label="__('Remove')"
          data-testid="remove-action"
          @click="remove"
        />
      </div>
    </div>
  </div>
</template>
