<script>
import { GlModal } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { refreshCurrentPage } from '~/lib/utils/url_utility';
import { __ } from '~/locale';
import { getExpiringSamlSession } from '../saml_sessions';
import { INTERVAL_SAML_MODAL } from '../constants';

export default {
  components: {
    GlModal,
  },
  props: {
    samlProviderId: {
      type: Number,
      required: true,
    },
    samlSessionsUrl: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      expirationTimestamp: null,
      modalId: uniqueId('reload-saml-modal-'),
      showModal: false,
    };
  },
  async created() {
    const session = await getExpiringSamlSession({
      samlProviderId: this.samlProviderId,
      url: this.samlSessionsUrl,
    });

    if (session) {
      this.expirationTimestamp = Date.now() + session.timeRemainingMs;
      this.intervalId = setInterval(this.checkStatus, INTERVAL_SAML_MODAL);
      document.addEventListener('visibilitychange', this.onDocumentVisible);
    }
  },
  beforeDestroy() {
    this.clearEvents();
  },
  methods: {
    clearEvents() {
      if (this.intervalId) {
        clearInterval(this.intervalId);
        document.removeEventListener('visibilitychange', this.onDocumentVisible);
        this.intervalId = null;
      }
    },
    checkStatus() {
      if (Date.now() >= this.expirationTimestamp) {
        this.showModal = true;
        this.clearEvents();
      }
    },
    onDocumentVisible() {
      if (document.visibilityState === 'visible') {
        this.checkStatus();
      }
    },
    reload() {
      refreshCurrentPage();
    },
  },
  reload: { text: __('Reload page') },
  cancel: { text: __('Cancel') },
};
</script>

<template>
  <gl-modal
    v-model="showModal"
    :modal-id="modalId"
    :title="s__('SAML|Your SAML session has expired')"
    :action-primary="$options.reload"
    :action-cancel="$options.cancel"
    aria-live="assertive"
    @primary="reload"
  >
    {{
      s__(
        'SAML|Your SAML session has expired. Please, reload the page and sign in again, if necessary.',
      )
    }}
  </gl-modal>
</template>
