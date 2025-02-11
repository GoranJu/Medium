<script>
import { GlIcon } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'DuoConfigurationSettingsRow',
  i18n: {
    disabledText: __('Not enabled'),
    enabledText: __('Enabled'),
  },
  components: {
    GlIcon,
  },
  props: {
    duoConfigurationSettingsRowTypeTitle: {
      type: String,
      required: true,
    },
    isEnabled: {
      type: Boolean,
      required: true,
    },
  },
};
</script>
<template>
  <div class="gl-border-b gl-w-full gl-text-gray-500">
    <div class="gl-my-3 gl-flex gl-flex-row gl-justify-between">
      <span data-testid="duo-configuration-row-title">{{
        duoConfigurationSettingsRowTypeTitle
      }}</span>
      <span v-if="isEnabled">
        <gl-icon name="check" :size="16" variant="success" />
        <span data-testid="duo-configuration-row-enabled-text">{{
          $options.i18n.enabledText
        }}</span>
      </span>
      <span v-else data-testid="duo-configuration-row-disabled-text">{{
        $options.i18n.disabledText
      }}</span>
    </div>
  </div>
</template>
