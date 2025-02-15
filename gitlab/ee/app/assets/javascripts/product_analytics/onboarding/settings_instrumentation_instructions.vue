<script>
import { GlButton, GlModal, GlSprintf, GlLink } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import InstrumentationInstructionsSdkDetails from './components/instrumentation_instructions_sdk_details.vue';
import InstrumentationInstructions from './components/instrumentation_instructions.vue';

export default {
  name: 'ProductAnalyticsSettingsInstrumentationInstructions',
  components: {
    GlButton,
    GlModal,
    GlSprintf,
    GlLink,
    InstrumentationInstructionsSdkDetails,
    InstrumentationInstructions,
  },
  inject: {
    collectorHost: {
      type: String,
    },
  },
  props: {
    trackingKey: {
      type: String,
      required: false,
      default: null,
    },
    dashboardsPath: {
      type: String,
      required: true,
    },
    onboardingPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      modalIsVisible: false,
    };
  },
  methods: {
    showModal() {
      this.modalIsVisible = true;
    },
    onModalChange(isVisible) {
      this.modalIsVisible = isVisible;
    },
  },
  i18n: {
    viewInstrumentationInstructionsButton: s__(
      'ProjectSettings|Your project is set up. %{instructionsLinkStart}View instrumentation instructions%{instructionsLinkEnd} and %{dashboardsLinkStart}Analytics Dashboards%{dashboardsLinkEnd}.',
    ),
    modalTitle: s__('ProjectSettings|Instrumentation details'),
    modalPrimaryButton: {
      text: __('Close'),
    },
  },
};
</script>
<template>
  <section class="gl-mb-5">
    <instrumentation-instructions-sdk-details :tracking-key="trackingKey" />

    <gl-sprintf :message="$options.i18n.viewInstrumentationInstructionsButton">
      <template #instructionsLink="{ content }">
        <gl-button category="secondary" variant="link" @click="showModal">{{ content }}</gl-button>
      </template>
      <template #dashboardsLink="{ content }">
        <gl-link :href="dashboardsPath">{{ content }}</gl-link>
      </template>
    </gl-sprintf>

    <gl-modal
      modal-id="analytics-instrumentation-instructions-modal"
      :title="$options.i18n.modalTitle"
      :action-primary="$options.i18n.modalPrimaryButton"
      :visible="modalIsVisible"
      size="lg"
      @change="onModalChange"
    >
      <instrumentation-instructions :dashboards-path="dashboardsPath" :tracking-key="trackingKey" />
    </gl-modal>
  </section>
</template>
