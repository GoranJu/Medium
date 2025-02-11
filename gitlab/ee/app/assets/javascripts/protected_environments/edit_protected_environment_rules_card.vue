<script>
import { GlButton } from '@gitlab/ui';
import { uniqueId } from 'lodash';

export default {
  components: {
    GlButton,
  },
  props: {
    ruleKey: {
      type: String,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
    addButtonText: {
      type: String,
      required: true,
    },
    environment: {
      type: Object,
      required: true,
    },
  },
  data() {
    return { isAddingRule: false, modalId: uniqueId('add-protected-environment-modal') };
  },
  computed: {
    rules() {
      return this.environment[this.ruleKey] || [];
    },
  },
  methods: {
    addRule(environment) {
      this.$emit('addRule', { environment, ruleKey: this.ruleKey });
    },
  },
};
</script>
<template>
  <div>
    <slot name="table"></slot>

    <div v-if="!rules.length" data-testid="empty-state" class="gl-bg-white gl-p-5">
      <slot name="empty-state"></slot>
    </div>

    <div class="gl-border-t gl-flex gl-items-center gl-p-5">
      <gl-button
        category="secondary"
        variant="confirm"
        class="gl-ml-auto"
        :loading="loading"
        @click="addRule(environment)"
      >
        {{ addButtonText }}
      </gl-button>
    </div>
  </div>
</template>
