<script>
import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import getCurrentLicense from 'ee/admin/subscriptions/show/graphql/queries/get_current_license.query.graphql';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import FeatureSettingsModelSelector from './feature_settings_model_selector.vue';

export default {
  name: 'FeatureSettingsTable',
  components: {
    GlTableLite,
    FeatureSettingsModelSelector,
    GlSkeletonLoader,
  },
  i18n: {
    errorMessage: s__(
      'AdminAIPoweredFeatures|An error occurred while loading the AI feature settings. Please try again.',
    ),
    errorLicenseMessage: s__(
      'AdminAIPoweredFeatures|An error occurred while loading the current license. Please try again.',
    ),
  },
  data() {
    return {
      aiFeatureSettings: [],
      currentLicense: {},
    };
  },
  fields: [
    {
      key: 'main_feature',
      label: s__('AdminAIPoweredFeatures|Main feature'),
      thClass: 'gl-w-1/3',
      tdClass: 'gl-content-center',
    },
    {
      key: 'sub_feature',
      label: s__('AdminAIPoweredFeatures|Sub feature'),
      thClass: 'gl-w-1/3',
      tdClass: 'gl-content-center',
    },
    {
      key: 'model_name',
      label: s__('AdminAIPoweredFeatures|Model name'),
      thClass: 'gl-w-1/3',
      tdClass: 'gl-content-center',
    },
  ],
  computed: {
    loaderItems() {
      return [
        {
          loaderWidth: {
            mainFeature: '225',
            subFeature: '200',
            modelName: '375',
          },
        },
        {
          loaderWidth: {
            mainFeature: '225',
            subFeature: '200',
            modelName: '375',
          },
        },
        {
          loaderWidth: {
            mainFeature: '200',
            subFeature: '75',
            modelName: '375',
          },
        },
      ];
    },
    isLoading() {
      return this.$apollo.loading;
    },
  },
  apollo: {
    currentLicense: {
      query: getCurrentLicense,
      update({ currentLicense }) {
        return currentLicense || {};
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.errorLicenseMessage,
          error,
          captureError: true,
        });
      },
    },
    aiFeatureSettings: {
      query: getAiFeatureSettingsQuery,
      update(data) {
        return data.aiFeatureSettings?.nodes || [];
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          error,
          captureError: true,
        });
      },
    },
  },
};
</script>
<template>
  <gl-table-lite
    :fields="$options.fields"
    :items="isLoading ? loaderItems : aiFeatureSettings"
    stacked="md"
    :hover="true"
    :selectable="false"
    fixed
  >
    <template #cell(main_feature)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :height="46" :width="600">
        <rect y="8" :width="item.loaderWidth.mainFeature" height="32" rx="10" />
      </gl-skeleton-loader>
      <span v-else>{{ item.mainFeature }}</span>
    </template>
    <template #cell(sub_feature)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :height="46" :width="600">
        <rect y="8" :width="item.loaderWidth.subFeature" height="32" rx="10" />
      </gl-skeleton-loader>
      <span v-else>{{ item.title }}</span>
    </template>
    <template #cell(model_name)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :height="46" :width="600">
        <rect y="8" :width="item.loaderWidth.modelName" height="32" rx="10" />
      </gl-skeleton-loader>
      <feature-settings-model-selector
        v-else
        :ai-feature-setting="item"
        :license="currentLicense"
      />
    </template>
  </gl-table-lite>
</template>
