<script>
import { GlTabs, GlTab, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import SelfHostedModelsTable from '../self_hosted_models/components/self_hosted_models_table.vue';
import FeatureSettingsTable from '../feature_settings/components/feature_settings_table.vue';
import { SELF_HOSTED_DUO_TABS } from './constants';

export default {
  name: 'SelfHostedDuoConfiguration',
  components: {
    GlTabs,
    GlTab,
    GlButton,
    SelfHostedModelsTable,
    FeatureSettingsTable,
    PageHeading,
  },
  i18n: {
    title: s__('AdminSelfHostedModels|Self-hosted models'),
    description: s__(
      'AdminSelfHostedModels|Manage GitLab Duo by configuring and assigning self-hosted models to AI-powered features.',
    ),
  },
  props: {
    tabId: {
      type: String,
      required: false,
      default: SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS,
    },
  },
  tabs: [
    {
      id: SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS,
      title: s__('AdminSelfHostedModels|Self-hosted models'),
    },
    {
      id: SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS,
      title: s__('AdminAIPoweredFeatures|AI-powered features'),
    },
  ],
  data() {
    return {
      currentTabIndex: this.$options.tabs.findIndex((tab) => tab.id === this.tabId) || 0,
    };
  },
  computed: {
    isSelfHostedModelsTab() {
      return this.tabId === SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS;
    },
  },
  watch: {
    currentTabIndex(newTabIdx) {
      const currentTabId = this.$options.tabs[newTabIdx].id;

      if (currentTabId === this.tabId) return;

      if (currentTabId === SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS) {
        this.navigateToFeaturesTab();
        return;
      }

      this.navigateToSelfHostedModelsTab();
    },
  },
  methods: {
    navigateToSelfHostedModelsTab() {
      this.$router.push({ name: 'index' });
    },
    navigateToFeaturesTab() {
      this.$router.push({ name: 'features' });
    },
  },
};
</script>

<template>
  <div>
    <page-heading>
      <template #heading>
        <div data-testid="self-hosted-title">{{ $options.i18n.title }}</div>
      </template>
      <template #description>{{ $options.i18n.description }}</template>
      <template #actions>
        <gl-button variant="confirm" to="new">
          {{ s__('AdminSelfHostedModels|Add self-hosted model') }}
        </gl-button>
      </template>
    </page-heading>
    <div class="top-area gl-border-b-0">
      <gl-tabs
        v-model="currentTabIndex"
        data-testid="self-hosted-duo-config-tabs"
        class="gl-flex gl-grow"
        nav-class="gl-border-b-0"
      >
        <gl-tab v-for="tab in $options.tabs" :key="tab.id" :data-testid="`${tab.id}-tab`">
          <template #title>
            {{ tab.title }}
          </template>
        </gl-tab>
      </gl-tabs>
    </div>
    <div v-if="isSelfHostedModelsTab">
      <self-hosted-models-table />
    </div>
    <div v-else>
      <feature-settings-table />
    </div>
  </div>
</template>
