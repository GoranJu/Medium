<script>
import { GlCard, GlButton } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { AVAILABILITY_OPTIONS } from '../constants';
import DuoConfigurationSettingsRow from './duo_configuration_settings_row.vue';

export default {
  name: 'DuoConfigurationSettingsInfoCard',
  i18n: {
    duoConfigurationSettingsTitle: __('GitLab Duo'),
    duoChangeConfigurationButtonText: s__('AiPowered|Change configuration'),
    experimentAndBetaFeaturesText: s__('AiPowered|Experiment and beta features'),
    betaSelfHostedModelsText: s__('AiPowered|Beta self-hosted models'),
    directConnectionsText: s__('AiPowered|Direct connections'),
    enabledText: __('Enabled'),
    defaultOnText: s__('AiPowered|On by default'),
    defaultOffText: s__('AiPowered|Off by default'),
    alwaysOffText: s__('AiPowered|Always off'),
  },
  components: {
    GlCard,
    GlButton,
    DuoConfigurationSettingsRow,
  },
  inject: {
    duoConfigurationPath: {},
    isSaaS: {},
    duoAvailability: {},
    directCodeSuggestionsEnabled: { default: false },
    experimentFeaturesEnabled: {},
    betaSelfHostedModelsEnabled: { default: false },
    areExperimentSettingsAllowed: {},
  },
  computed: {
    onSelfManaged() {
      return !this.isSaaS;
    },
    getAvailabilityStatus() {
      switch (this.duoAvailability) {
        case AVAILABILITY_OPTIONS.DEFAULT_ON:
          return this.$options.i18n.defaultOnText;
        case AVAILABILITY_OPTIONS.DEFAULT_OFF:
          return this.$options.i18n.defaultOffText;
        case AVAILABILITY_OPTIONS.NEVER_ON:
          return this.$options.i18n.alwaysOffText;
        default:
          return null;
      }
    },
  },
};
</script>
<template>
  <gl-card
    header-class="gl-bg-transparent gl-border-none gl-pb-0"
    footer-class="gl-bg-transparent gl-border-none gl-flex-end"
    class="gl-justify-between"
  >
    <template #default>
      <section class="gl-flex gl-flex-col">
        <h2 class="gl-m-0 gl-text-lg" data-testid="duo-configuration-settings-info">
          {{ $options.i18n.duoConfigurationSettingsTitle }}
        </h2>
        <p class="gl-mb-3 gl-text-size-h-display gl-font-bold">
          <span data-testid="configuration-status">{{ getAvailabilityStatus }}</span>
        </p>
      </section>
      <section v-if="areExperimentSettingsAllowed">
        <duo-configuration-settings-row
          :duo-configuration-settings-row-type-title="$options.i18n.experimentAndBetaFeaturesText"
          :is-enabled="experimentFeaturesEnabled"
        />
      </section>
      <section v-if="onSelfManaged">
        <duo-configuration-settings-row
          :duo-configuration-settings-row-type-title="$options.i18n.directConnectionsText"
          :is-enabled="directCodeSuggestionsEnabled"
        />
        <duo-configuration-settings-row
          :duo-configuration-settings-row-type-title="$options.i18n.betaSelfHostedModelsText"
          :is-enabled="betaSelfHostedModelsEnabled"
        />
      </section>
    </template>
    <template #footer>
      <div data-testid="duo-configuration-settings-action-buttons">
        <gl-button category="primary" variant="default" :href="duoConfigurationPath">{{
          $options.i18n.duoChangeConfigurationButtonText
        }}</gl-button>
      </div>
    </template>
  </gl-card>
</template>
