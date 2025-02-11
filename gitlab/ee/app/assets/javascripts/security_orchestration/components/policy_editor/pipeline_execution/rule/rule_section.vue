<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  i18n: {
    conditionText: s__(
      'SecurityOrchestration|Configure your conditions in the pipeline execution file. %{linkStart}What can pipeline execution do?%{linkEnd}',
    ),
    helpPageLink: helpPagePath('user/application_security/policies/pipeline_execution_policies'),
  },
  components: {
    GlLink,
    GlSprintf,
  },
};
</script>

<template>
  <div
    class="security-policies-bg-subtle gl-flex gl-flex-col gl-gap-3 gl-rounded-base gl-p-5 lg:gl-flex-row"
  >
    <gl-sprintf :message="$options.i18n.conditionText">
      <template #link="{ content }">
        <gl-link :href="$options.i18n.helpPageLink" target="_blank">{{ content }}</gl-link>
      </template>
    </gl-sprintf>
  </div>
</template>
