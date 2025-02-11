<script>
import GeoSiteProgressBar from 'ee/geo_sites/components/details/geo_site_progress_bar.vue';

export default {
  name: 'GeoSiteReplicationStatusMobile',
  components: {
    GeoSiteProgressBar,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    translations: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mb-5 gl-flex gl-flex-col" data-testid="sync-status">
      <span class="gl-mb-3 gl-text-sm">{{ translations.syncStatus }}</span>
      <geo-site-progress-bar
        v-if="item.syncValues"
        :title="
          /* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */
          sprintf(translations.progressBarSyncTitle, {
            component: item.component,
          }) /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */
        "
        :target="`mobile-sync-progress-${item.component}`"
        :values="item.syncValues"
      />
      <span v-else class="gl-text-sm gl-text-subtle">{{ translations.nA }}</span>
    </div>
    <div class="gl-flex gl-flex-col" data-testid="verification-status">
      <span class="gl-mb-3 gl-text-sm">{{ translations.verifStatus }}</span>
      <geo-site-progress-bar
        v-if="item.verificationValues"
        :title="
          /* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */
          sprintf(translations.progressBarVerifTitle, {
            component: item.component,
          }) /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */
        "
        :target="`mobile-verification-progress-${item.component}`"
        :values="item.verificationValues"
        :success-label="translations.verified"
        :unavailable-label="translations.nothingToVerify"
      />
      <span v-else class="gl-text-sm gl-text-subtle">{{ translations.nA }}</span>
    </div>
  </div>
</template>
