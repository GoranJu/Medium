<script>
import { GlSprintf, GlFormCheckbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

export default {
  name: 'AiModelsForm',
  i18n: {
    title: s__('AiPowered|Self-hosted AI models'),
    checkBoxLabel: s__('AiPowered|Use beta self-hosted models features'),
    checkboxHelpText: s__(
      'AiPowered|Enabling this feature is your acceptance of the %{linkStart}GitLab Testing Agreement%{linkEnd}.',
    ),
  },
  components: {
    GlSprintf,
    PromoPageLink,
    GlFormCheckbox,
  },
  inject: ['betaSelfHostedModelsEnabled'],
  testingAgreementPath: '/handbook/legal/testing-agreement/',
  data() {
    return {
      aiModelsEnabled: this.betaSelfHostedModelsEnabled,
    };
  },
  methods: {
    checkBoxChanged(value) {
      this.$emit('change', value);
    },
  },
};
</script>
<template>
  <div>
    <h3 class="gl-text-base">{{ $options.i18n.title }}</h3>
    <gl-form-checkbox v-model="aiModelsEnabled" @change="checkBoxChanged">
      <span data-testid="label">{{ $options.i18n.checkBoxLabel }}</span>
      <template #help>
        <gl-sprintf :message="$options.i18n.checkboxHelpText">
          <template #link="{ content }">
            <promo-page-link
              :path="$options.testingAgreementPath"
              target="_blank"
              rel="noopener noreferrer"
            >
              {{ content }}
            </promo-page-link>
          </template>
        </gl-sprintf>
      </template>
    </gl-form-checkbox>
  </div>
</template>
