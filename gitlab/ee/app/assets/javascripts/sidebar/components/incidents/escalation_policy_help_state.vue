<script>
import { GlButton } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { i18nHelpText } from '../../constants';

export default {
  POLICIES_PATH: helpPagePath('operations/incident_management/escalation_policies.md'),
  i18n: i18nHelpText,
  components: {
    GlButton,
  },
};
</script>

<template>
  <transition name="help-state-toggle">
    <div
      class="sidebar-help-state gl-border-1 gl-border-default gl-bg-white gl-border-b-solid gl-border-t-solid"
    >
      <div>
        <h4>{{ $options.i18n.title }}</h4>
        <p>{{ $options.i18n.detail }}</p>
        <gl-button :href="$options.POLICIES_PATH">{{ $options.i18n.linkText }}</gl-button>
      </div>
    </div>
  </transition>
</template>
