<script>
import { unescape } from 'lodash';
import { GlLink, GlSprintf, GlAlert } from '@gitlab/ui';
import { sanitize } from '~/lib/dompurify';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCommonSettingsForm from './ai_common_settings_form.vue';

export default {
  name: 'AiCommonSettings',
  components: {
    GlLink,
    GlSprintf,
    GlAlert,
    SettingsBlock,
    AiCommonSettingsForm,
    PageHeading,
  },
  i18n: {
    confirmButtonText: __('Save changes'),
    settingsBlockTitle: __('GitLab Duo features'),
    settingsBlockDescription: s__(
      'AiPowered|Configure AI-powered GitLab Duo features. %{linkStart}Which features?%{linkEnd}',
    ),
    configurationPageTitle: s__('AiPowered|Configuration'),
    movedAlertTitle: s__('AiPowered|GitLab Duo settings have moved'),
    movedAlertDescriptionText: s__(
      'AiPowered|To make it easier to configure GitLab Duo, the settings have moved to a more visible location. To access them, go to ',
    ),
    movedAlertButton: s__('AiPowered|View GitLab Duo settings'),
    groupSettingsPath: unescape(sanitize(__('Settings &gt; GitLab Duo'), { ALLOWED_TAGS: [] })),
    globalSettingsPath: unescape(sanitize(__('Admin Area &gt; GitLab Duo'), { ALLOWED_TAGS: [] })),
  },
  inject: [
    'duoAvailability',
    'experimentFeaturesEnabled',
    'onGeneralSettingsPage',
    'configurationSettingsPath',
    'showRedirectBanner',
  ],
  props: {
    hasParentFormChanged: {
      type: Boolean,
      required: false,
      default: false,
    },
    isGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      availability: this.duoAvailability,
      experimentsEnabled: this.experimentFeaturesEnabled,
    };
  },
  computed: {
    movedAlertDescription() {
      const path = this.isGroup
        ? this.$options.i18n.groupSettingsPath
        : this.$options.i18n.globalSettingsPath;
      return `${this.$options.i18n.movedAlertDescriptionText}%{linkStart}${path}%{linkEnd}.`;
    },
  },
  methods: {
    submitForm() {
      this.$emit('submit', {
        duoAvailability: this.availability,
        experimentFeaturesEnabled: this.experimentsEnabled,
      });
    },
    onRadioChanged(value) {
      this.availability = value;
    },
    onCheckboxChanged(value) {
      this.experimentsEnabled = value;
    },
  },
  aiFeaturesHelpPath: helpPagePath('user/ai_features'),
};
</script>
<template>
  <div>
    <template v-if="onGeneralSettingsPage">
      <settings-block class="gl-mb-5 !gl-pt-5" :title="$options.i18n.settingsBlockTitle">
        <template v-if="!showRedirectBanner" #description>
          <gl-sprintf
            data-testid="general-settings-subtitle"
            :message="
              s__(
                'AiPowered|Configure AI-powered GitLab Duo features. %{linkStart}Which features?%{linkEnd}',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.aiFeaturesHelpPath">{{ content }} </gl-link>
            </template>
          </gl-sprintf>
        </template>
        <template #default>
          <gl-alert
            v-if="showRedirectBanner"
            variant="info"
            :title="$options.i18n.movedAlertTitle"
            :dismissible="false"
            class="gl-mb-5"
            data-testid="duo-moved-settings-alert"
          >
            <gl-sprintf
              data-testid="duo-moved-settings-alert-description-text"
              :message="movedAlertDescription"
            >
              <template #link="{ content }">
                <gl-link class="!gl-no-underline" :href="configurationSettingsPath">{{
                  content
                }}</gl-link>
              </template>
            </gl-sprintf>
          </gl-alert>
          <ai-common-settings-form
            v-else
            :duo-availability="duoAvailability"
            :experiment-features-enabled="experimentFeaturesEnabled"
            :has-parent-form-changed="hasParentFormChanged"
            @submit="submitForm"
            @radio-changed="onRadioChanged"
            @checkbox-changed="onCheckboxChanged"
          >
            <template #ai-common-settings-top>
              <slot name="ai-common-settings-top"></slot>
            </template>
          </ai-common-settings-form>
        </template>
      </settings-block>
    </template>
    <template v-else>
      <page-heading :heading="$options.i18n.configurationPageTitle">
        <template #description>
          <span data-testid="configuration-page-subtitle">
            <gl-sprintf :message="$options.i18n.settingsBlockDescription">
              <template #link="{ content }">
                <gl-link :href="$options.aiFeaturesHelpPath">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </span>
        </template>
      </page-heading>
      <ai-common-settings-form
        :duo-availability="duoAvailability"
        :experiment-features-enabled="experimentFeaturesEnabled"
        :has-parent-form-changed="hasParentFormChanged"
        @submit="submitForm"
        @radio-changed="onRadioChanged"
        @checkbox-changed="onCheckboxChanged"
      >
        <template #ai-common-settings-top>
          <slot name="ai-common-settings-top"></slot>
        </template>
        <template #ai-common-settings-bottom>
          <slot name="ai-common-settings-bottom"></slot>
        </template>
      </ai-common-settings-form>
    </template>
  </div>
</template>
