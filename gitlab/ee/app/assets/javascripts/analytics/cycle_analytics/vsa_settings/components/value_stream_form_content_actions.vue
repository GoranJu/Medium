<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import { i18n } from 'ee/analytics/cycle_analytics/components/create_value_stream_form/constants';

const { FORM_TITLE, EDIT_FORM_ACTION, BTN_ADD_STAGE } = i18n;

export default {
  name: 'ValueStreamFormContentActions',
  components: {
    GlButton,
  },
  props: {
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    valueStreamPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  i18n: {
    newValueStreamAction: FORM_TITLE,
    saveValueStreamAction: EDIT_FORM_ACTION,
    addStageAction: BTN_ADD_STAGE,
    cancelAction: __('Cancel'),
  },
  computed: {
    primaryButtonText() {
      return this.isEditing
        ? this.$options.i18n.saveValueStreamAction
        : this.$options.i18n.newValueStreamAction;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-gap-3 sm:gl-w-auto sm:gl-flex-row">
    <gl-button
      data-testid="primary-button"
      variant="confirm"
      :loading="isLoading"
      @click="$emit('clickPrimaryAction')"
      >{{ primaryButtonText }}</gl-button
    >
    <gl-button
      data-testid="add-button"
      category="secondary"
      variant="confirm"
      :disabled="isLoading"
      @click="$emit('clickAddStageAction')"
      >{{ $options.i18n.addStageAction }}</gl-button
    >
    <gl-button data-testid="cancel-button" :href="valueStreamPath" :disabled="isLoading">{{
      $options.i18n.cancelAction
    }}</gl-button>
  </div>
</template>
