<script>
import { i18n } from 'ee/analytics/cycle_analytics/components/create_value_stream_form/constants';
import ValueStreamForm from './value_stream_form.vue';

const { FORM_TITLE, EDIT_FORM_TITLE } = i18n;

export default {
  name: 'VSASettingsApp',
  components: {
    ValueStreamForm,
  },
  props: {
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    pageHeader() {
      return this.isEditing
        ? this.$options.i18n.editValueStreamHeader
        : this.$options.i18n.newValueStreamHeader;
    },
  },
  i18n: {
    newValueStreamHeader: FORM_TITLE,
    editValueStreamHeader: EDIT_FORM_TITLE,
  },
};
</script>

<template>
  <div>
    <h1 data-testid="vsa-settings-page-header" class="page-title gl-text-size-h-display">
      {{ pageHeader }}
    </h1>
    <value-stream-form :is-editing="isEditing" />
  </div>
</template>
