<script>
import { GlLink, GlSprintf, GlForm, GlAlert, GlButton } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import DuoAvailability from 'ee/ai/settings/components/duo_availability_form.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

export default {
  name: 'AmazonQSettings',
  components: {
    GlLink,
    GlSprintf,
    GlForm,
    GlAlert,
    GlButton,
    SettingsBlock,
    DuoAvailability,
  },
  i18n: {
    confirmButtonText: __('Save changes'),
    neverOnWarning: s__(
      'AmazonQ|When you save, Amazon Q will be turned off for all subgroups, and projects, even if they have previously enabled it.%{br}This will also remove the Amazon Q service account from these groups and projects.',
    ),
    settingsBlockTitle: __('Amazon Q'),
    settingsBlockDescription: s__(
      'AmazonQ|Use GitLab Duo with Amazon Q to create and review merge requests and upgrade Java. GitLab Duo with Amazon Q is separate from GitLab Duo Pro and Enterprise. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
  props: {
    initAvailability: {
      type: String,
      required: false,
      default: AVAILABILITY_OPTIONS.DEFAULT_ON,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      availability: this.initAvailability,
    };
  },
  computed: {
    hasAvailabilityChanged() {
      return this.availability !== this.initAvailability;
    },
    warningMessage() {
      if (this.hasAvailabilityChanged && this.availability === AVAILABILITY_OPTIONS.NEVER_ON) {
        return this.$options.i18n.neverOnWarning;
      }

      return null;
    },
  },
  methods: {
    submitForm() {
      this.$emit('submit', {
        availability: this.availability,
      });
    },
    onRadioChanged(value) {
      this.availability = value;
    },
  },
  helpPath: helpPagePath('user/duo_amazon_q/_index.md'),
};
</script>
<template>
  <settings-block id="js-amazon-q-settings" :title="$options.i18n.settingsBlockTitle">
    <template #description>
      <gl-sprintf :message="$options.i18n.settingsBlockDescription">
        <template #link="{ content }">
          <gl-link :href="$options.helpPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template #default>
      <gl-form @submit.prevent="submitForm">
        <duo-availability :duo-availability="availability" @change="onRadioChanged" />
        <gl-alert v-if="warningMessage" :dismissible="false" variant="warning">
          <gl-sprintf :message="warningMessage">
            <template #br>
              <br />
            </template>
          </gl-sprintf>
        </gl-alert>
        <div class="gl-mt-6">
          <gl-button
            type="submit"
            variant="confirm"
            :disabled="!hasAvailabilityChanged"
            :loading="isLoading"
          >
            {{ $options.i18n.confirmButtonText }}
          </gl-button>
        </div>
      </gl-form>
    </template>
  </settings-block>
</template>
