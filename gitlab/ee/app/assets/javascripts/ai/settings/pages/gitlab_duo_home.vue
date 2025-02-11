<script>
import { __, s__ } from '~/locale';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import DuoSeatUtilizationInfoCard from '../components/duo_seat_utilization_info_card.vue';
import DuoConfigurationSettingsInfoCard from '../components/duo_configuration_settings_info_card.vue';

export default {
  name: 'GitlabDuoHome',
  components: {
    CodeSuggestionsUsage,
    HealthCheckList,
    DuoSeatUtilizationInfoCard,
    DuoConfigurationSettingsInfoCard,
  },
  inject: ['isSaaS'],
  i18n: {
    gitlabDuoHomeTitle: __('GitLab Duo'),
    gitlabDuoHomeSubtitle: s__(
      'AiPowered|Monitor, manage, and customize AI features to ensure efficient utilization and alignment.',
    ),
  },
};
</script>

<template>
  <code-suggestions-usage
    :title="$options.i18n.gitlabDuoHomeTitle"
    :subtitle="$options.i18n.gitlabDuoHomeSubtitle"
    :force-hide-title="false"
    v-bind="$attrs"
  >
    <template #health-check>
      <health-check-list v-if="!isSaaS" />
    </template>
    <template #duo-card="{ totalValue, usageValue, duoTier }">
      <section class="gl-grid gl-gap-5 md:gl-grid-cols-2">
        <duo-seat-utilization-info-card
          :total-value="totalValue"
          :usage-value="usageValue"
          :duo-tier="duoTier"
        />
        <duo-configuration-settings-info-card />
      </section>
    </template>
  </code-suggestions-usage>
</template>
