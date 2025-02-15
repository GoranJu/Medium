<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { s__ } from '~/locale';

export default {
  SCAN_EXECUTION_ACTION_LIMIT_PATH: helpPagePath(
    'user/application_security/policies/scan_execution_policies',
  ),
  BANNER_STORAGE_KEY: 'security_policies_exceeding_actions_18',
  i18n: {
    bannerTitle: s__(
      'SecurityOrchestration|Maximum action limit for scan execution policies will be enabled in 18.0',
    ),
    bannerDescription: s__(
      'SecurityOrchestration|SecurityOrchestration|Scan execution policies with more than %{maxCount} actions detected. Those policies will not work after GitLab 18.0 (May 15, 2025). Before then you must edit these policies to reduce the number of actions.',
    ),
  },
  name: 'ExceedingActionsBanner',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
    LocalStorageSync,
  },
  inject: ['maxScanExecutionPolicyActions'],
  data() {
    return {
      alertDismissed: false,
    };
  },
  mounted() {
    this.emitChange();
  },
  methods: {
    dismissAlert() {
      this.alertDismissed = true;
      this.emitChange();
    },
    emitChange() {
      this.$emit('dismiss', this.alertDismissed);
    },
  },
};
</script>

<template>
  <local-storage-sync v-model="alertDismissed" :storage-key="$options.BANNER_STORAGE_KEY">
    <gl-alert
      v-if="!alertDismissed"
      :title="$options.i18n.bannerTitle"
      :dismissible="true"
      @dismiss="dismissAlert"
    >
      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.bannerDescription">
          <template #link="{ content }">
            <gl-link :href="$options.SCAN_EXECUTION_ACTION_LIMIT_PATH" target="_blank">{{
              content
            }}</gl-link>
          </template>
          <template #maxCount>
            {{ maxScanExecutionPolicyActions }}
          </template>
        </gl-sprintf>
      </p>
    </gl-alert>
  </local-storage-sync>
</template>
