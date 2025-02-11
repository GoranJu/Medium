<script>
import { updateGroupSettings } from 'ee/api/groups_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __ } from '~/locale';
import AiCommonSettings from '../components/ai_common_settings.vue';

const EarlyAccessProgramBanner = () => import('../components/early_access_program_banner.vue');

export default {
  name: 'AiGroupSettings',
  components: {
    AiCommonSettings,
    EarlyAccessProgramBanner,
  },
  i18n: {
    successMessage: __('Group was successfully updated.'),
    errorMessage: __(
      'An error occurred while retrieving your settings. Reload the page to try again.',
    ),
  },
  inject: ['showEarlyAccessBanner'],
  props: {
    redirectPath: {
      type: String,
      required: false,
      default: '',
    },
    updateId: {
      type: String,
      required: true,
    },
  },
  data: () => ({ isLoading: false }),
  methods: {
    async updateSettings({ duoAvailability, experimentFeaturesEnabled }) {
      try {
        this.isLoading = true;

        await updateGroupSettings(this.updateId, {
          duo_availability: duoAvailability,
          experiment_features_enabled: experimentFeaturesEnabled,
        });

        visitUrlWithAlerts(this.redirectPath, [
          {
            id: 'organization-group-successfully-updated',
            message: this.$options.i18n.successMessage,
            variant: VARIANT_INFO,
          },
        ]);
      } catch (error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          captureError: true,
          error,
        });
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>
<template>
  <ai-common-settings :is-group="true" @submit="updateSettings">
    <template #ai-common-settings-top>
      <early-access-program-banner v-if="showEarlyAccessBanner" />
    </template>
  </ai-common-settings>
</template>
