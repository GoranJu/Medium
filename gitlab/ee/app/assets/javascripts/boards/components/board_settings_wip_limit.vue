<script>
import { GlButton, GlFormInput } from '@gitlab/ui';
import { __, n__ } from '~/locale';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import { setError } from '~/boards/graphql/cache_updates';
import listUpdateLimitMetricsMutation from '../graphql/list_update_limit_metrics.mutation.graphql';

export default {
  i18n: {
    wipLimitText: __('Work in progress limit'),
    editButtonText: __('Edit'),
    noneText: __('None'),
    inputPlaceholderText: __('Enter number of issues'),
    removeLimitText: __('Remove limit'),
    updateListError: __('Something went wrong while updating your list settings'),
  },
  components: {
    GlButton,
    GlFormInput,
  },
  directives: {
    autofocusonshow,
  },
  props: {
    activeListId: {
      type: String,
      required: true,
    },
    maxIssueCount: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      currentWipLimit: null,
      edit: false,
      updating: false,
    };
  },
  computed: {
    wipLimitTypeText() {
      return n__('%d issue', '%d issues', this.maxIssueCount);
    },
    wipLimitIsSet() {
      return this.maxIssueCount !== 0;
    },
    activeListWipLimit() {
      return this.wipLimitIsSet ? this.wipLimitTypeText : this.$options.i18n.noneText;
    },
  },
  methods: {
    showInput() {
      this.edit = true;
      this.currentWipLimit = this.maxIssueCount > 0 ? this.maxIssueCount : null;
    },
    handleWipLimitChange(wipLimit) {
      if (wipLimit === '') {
        this.currentWipLimit = null;
      } else {
        this.currentWipLimit = Number(wipLimit);
      }
    },
    onEnter() {
      this.offFocus();
    },
    resetStateAfterUpdate() {
      this.edit = false;
      this.updating = false;
      this.currentWipLimit = null;
    },
    offFocus() {
      if (this.currentWipLimit !== this.maxIssueCount && this.currentWipLimit !== null) {
        this.updating = true;
        // need to reassign bc were clearing the ref in resetStateAfterUpdate.
        const wipLimit = this.currentWipLimit;

        this.updateWipLimit(this.activeListId, wipLimit);
      } else {
        this.edit = false;
      }
    },
    clearWipLimit() {
      this.updateWipLimit(this.activeListId, 0);
    },
    async updateWipLimit(listId, maxIssueCount) {
      try {
        await this.$apollo.mutate({
          mutation: listUpdateLimitMetricsMutation,
          variables: {
            input: {
              listId,
              maxIssueCount,
            },
          },
        });
        this.resetStateAfterUpdate();
      } catch (error) {
        setError({
          error,
          message: this.$options.i18n.updateListError,
        });
      }
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-justify-between">
    <div class="gl-mb-2 gl-flex gl-items-center gl-justify-between">
      <label class="m-0">{{ $options.i18n.wipLimitText }}</label>
      <gl-button
        class="text-dark gl-h-full gl-border-0"
        category="tertiary"
        size="small"
        data-testid="edit-button"
        @click="showInput"
        >{{ $options.i18n.editButtonText }}</gl-button
      >
    </div>
    <gl-form-input
      v-if="edit"
      v-autofocusonshow
      :value="currentWipLimit"
      :disabled="updating"
      :placeholder="$options.i18n.inputPlaceholderText"
      trim
      number
      type="number"
      min="0"
      @input="handleWipLimitChange"
      @keydown.enter.native="onEnter"
      @blur="offFocus"
    />
    <div v-else class="gl-flex gl-items-center">
      <p class="gl-m-0 gl-font-bold gl-text-subtle" data-testid="wip-limit">
        {{ activeListWipLimit }}
      </p>
      <template v-if="wipLimitIsSet">
        <span class="m-1">-</span>
        <gl-button
          class="gl-h-full gl-border-0 gl-text-subtle"
          category="tertiary"
          size="small"
          data-testid="remove-limit"
          @click="clearWipLimit"
          >{{ $options.i18n.removeLimitText }}</gl-button
        >
      </template>
    </div>
  </div>
</template>
