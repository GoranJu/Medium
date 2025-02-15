<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { sprintf, __ } from '~/locale';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';

export default {
  i18n: {
    lock: __('Lock'),
    unlock: __('Unlock'),
    modalTitleLock: __('Lock file?'),
    modalTitleUnlock: __('Unlock file?'),
    actionCancel: __('Cancel'),
  },
  components: {
    GlButton,
    GlModal,
  },
  props: {
    name: {
      type: String,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    isLocked: {
      type: Boolean,
      required: true,
    },
    canLock: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      isModalVisible: false,
      lockLoading: false,
      locked: this.isLocked,
    };
  },
  computed: {
    lockButtonTitle() {
      return this.locked ? this.$options.i18n.unlock : this.$options.i18n.lock;
    },
    modalTitle() {
      return this.locked ? this.$options.i18n.modalTitleUnlock : this.$options.i18n.modalTitleLock;
    },
    lockConfirmText() {
      return sprintf(__('Are you sure you want to %{action} %{name}?'), {
        action: this.lockButtonTitle.toLowerCase(),
        name: this.name,
      });
    },
  },
  watch: {
    isLocked(val) {
      this.locked = val;
    },
  },
  methods: {
    hideModal() {
      this.isModalVisible = false;
    },
    handleModalPrimary() {
      this.toggleLock();
    },
    showModal() {
      this.isModalVisible = true;
    },
    toggleLock() {
      this.lockLoading = true;
      const locked = !this.locked;
      this.$apollo
        .mutate({
          mutation: lockPathMutation,
          variables: {
            filePath: this.path,
            projectPath: this.projectPath,
            lock: locked,
          },
        })
        .catch((error) => {
          createAlert({ message: error, captureError: true, error });
        })
        .finally(() => {
          this.locked = locked;
          this.lockLoading = false;
        });
    },
  },
};
</script>

<template>
  <gl-button :disabled="!canLock" :loading="lockLoading" @click="showModal">
    {{ lockButtonTitle }}
    <gl-modal
      modal-id="lock-file-modal"
      :visible="isModalVisible"
      :title="modalTitle"
      :action-primary="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ {
        text: lockButtonTitle,
        attributes: { variant: 'confirm', 'data-testid': 'confirm-ok-button' },
      } /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
      :action-cancel="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ {
        text: $options.i18n.actionCancel,
      } /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
      @primary="handleModalPrimary"
      @hide="hideModal"
    >
      <p>
        {{ lockConfirmText }}
      </p>
    </gl-modal>
  </gl-button>
</template>
