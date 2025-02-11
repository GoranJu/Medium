<script>
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { subscriptionTypes } from 'ee/admin/subscriptions/show/constants';
import { RELEASE_STATES } from '../../self_hosted_models/constants';
import updateAiFeatureSetting from '../graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import getSelfHostedModelsQuery from '../../self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import ModelSelectDropdown from '../../custom_models/shared/model_select_dropdown.vue';

const PROVIDERS = {
  DISABLED: 'disabled',
  VENDORED: 'vendored',
  SELF_HOSTED: 'self_hosted',
};

export default {
  name: 'FeatureSettingsModelSelector',
  components: {
    ModelSelectDropdown,
  },
  props: {
    aiFeatureSetting: {
      type: Object,
      required: true,
    },
    license: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    defaultErrorMessage: s__(
      'AdminSelfHostedModels|An error occurred while updating the self-hosted model, please try again.',
    ),
    successMessage: s__('AdminSelfHostedModels|Successfully updated %{mainFeature} / %{title}'),
  },
  data() {
    const { provider, selfHostedModel, validModels } = this.aiFeatureSetting;
    const { type: licenseType } = this.license;

    const selectedOption = provider === PROVIDERS.SELF_HOSTED ? selfHostedModel?.id : provider;

    return {
      provider,
      selfHostedModelId: selfHostedModel?.id,
      compatibleModels: validModels?.nodes,
      isOnlineCloudLicense: licenseType === subscriptionTypes.ONLINE_CLOUD,
      selectedOption,
      isSaving: false,
    };
  },
  computed: {
    listItems() {
      const gaModels = this.compatibleModels.filter(
        ({ releaseState }) => releaseState === RELEASE_STATES.GA,
      );
      const betaModels = this.compatibleModels.filter(
        ({ releaseState }) => releaseState === RELEASE_STATES.BETA,
      );

      // sort compatible models by releaseState
      const modelOptions = [...gaModels, ...betaModels].map(
        ({ name, modelDisplayName, id, releaseState }) => ({
          value: id,
          text: `${name} (${modelDisplayName})`,
          releaseState,
        }),
      );

      // Add an option to disable the feature
      const disableOption = {
        value: PROVIDERS.DISABLED,
        text: s__('AdminAIPoweredFeatures|Disabled'),
      };

      const vendoredOption = {
        value: PROVIDERS.VENDORED,
        text: s__('AdminAIPoweredFeatures|GitLab AI Vendor'),
      };

      if (this.isOnlineCloudLicense) {
        return [...modelOptions, vendoredOption, disableOption];
      }

      return [...modelOptions, disableOption];
    },
    selectedModel() {
      return this.compatibleModels.find((m) => m.id === this.selfHostedModelId);
    },
    selectedOptionItem() {
      return this.listItems.find((item) => item.value === this.selectedOption);
    },
    dropdownToggleText() {
      if (this.provider === PROVIDERS.DISABLED) {
        return s__('AdminAIPoweredFeatures|Disabled');
      }
      if (this.isOnlineCloudLicense && this.provider === PROVIDERS.VENDORED) {
        return s__('AdminAIPoweredFeatures|GitLab AI Vendor');
      }
      if (this.selectedModel) {
        return `${this.selectedModel.name} (${this.selectedModel.modelDisplayName})`;
      }

      return s__('AdminAIPoweredFeatures|Select a self-hosted model');
    },
  },
  methods: {
    async onSelect(option) {
      this.isSaving = true;

      try {
        const selectedOption = [PROVIDERS.DISABLED, PROVIDERS.VENDORED].includes(option)
          ? {
              option,
              provider: option,
              selfHostedModelId: null,
            }
          : {
              option,
              provider: PROVIDERS.SELF_HOSTED,
              selfHostedModelId: option,
            };

        const { data } = await this.$apollo.mutate({
          mutation: updateAiFeatureSetting,
          variables: {
            input: {
              feature: this.aiFeatureSetting.feature.toUpperCase(),
              provider: selectedOption.provider.toUpperCase(),
              aiSelfHostedModelId: selectedOption.selfHostedModelId,
            },
          },
          refetchQueries: [
            { query: getSelfHostedModelsQuery },
            { query: getAiFeatureSettingsQuery },
          ],
        });

        if (data) {
          const { errors } = data.aiFeatureSettingUpdate;

          if (errors.length > 0) {
            throw new Error(errors[0]);
          }

          this.updateSelection(selectedOption);
          this.isSaving = false;
          this.$toast.show(this.successMessage(this.aiFeatureSetting));
        }
      } catch (error) {
        createAlert({
          message: this.errorMessage(error),
          error,
          captureError: true,
        });
        this.isSaving = false;
      }
    },
    updateSelection(selectedOption) {
      this.selectedOption = selectedOption.option;
      this.provider = selectedOption.provider;
      this.selfHostedModelId = selectedOption.selfHostedModelId;
    },
    errorMessage(error) {
      return error.message || this.$options.i18n.defaultErrorMessage;
    },
    successMessage(aiFeatureSetting) {
      return sprintf(this.$options.i18n.successMessage, {
        mainFeature: aiFeatureSetting.mainFeature,
        title: aiFeatureSetting.title,
      });
    },
  },
};
</script>
<template>
  <model-select-dropdown
    :selected-option="selectedOptionItem"
    :items="listItems"
    :dropdown-toggle-text="dropdownToggleText"
    :is-loading="isSaving"
    is-feature-setting-dropdown
    @select="onSelect"
  />
</template>
