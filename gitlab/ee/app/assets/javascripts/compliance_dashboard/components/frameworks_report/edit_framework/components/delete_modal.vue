<script>
import { GlModal, GlSprintf } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import { i18n } from '../constants';

export default {
  components: {
    GlModal,
    GlSprintf,
  },
  props: {
    name: {
      type: String,
      required: true,
    },
  },
  computed: {
    title() {
      return sprintf(i18n.deleteModalTitle, { framework: this.name }, false);
    },
  },
  methods: {
    show() {
      this.$refs.modal.show();
    },
  },
  i18n,

  buttonProps: {
    primary: {
      text: i18n.deleteButtonText,
      attributes: { category: 'primary', variant: 'danger' },
    },
    cancel: {
      text: __('Cancel'),
    },
  },
};
</script>
<template>
  <gl-modal
    ref="modal"
    :title="title"
    modal-id="delete-framework-modal"
    :action-primary="$options.buttonProps.primary"
    :action-cancel="$options.buttonProps.cancel"
    @primary="$emit('delete')"
  >
    <gl-sprintf :message="$options.i18n.deleteModalMessage">
      <template #framework>
        <strong>{{ name }}</strong>
      </template>
    </gl-sprintf>
  </gl-modal>
</template>
