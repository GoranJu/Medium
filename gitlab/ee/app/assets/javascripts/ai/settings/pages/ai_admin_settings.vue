<script>
import { updateApplicationSettings } from '~/rest_api';
import axios from '~/lib/utils/axios_utils';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __ } from '~/locale';
import AiCommonSettings from '../components/ai_common_settings.vue';
import CodeSuggestionsConnectionForm from '../components/code_suggestions_connection_form.vue';
import DuoExpandedLoggingForm from '../components/duo_expanded_logging_form.vue';
import AiModelsForm from '../components/ai_models_form.vue';
import AiGatewayUrlInputForm from '../components/ai_gateway_url_input_form.vue';
import updateAiSettingsMutation from '../../graphql/update_ai_settings.mutation.graphql';

export default {
  name: 'AiAdminSettings',
  components: {
    AiCommonSettings,
    AiGatewayUrlInputForm,
    AiModelsForm,
    CodeSuggestionsConnectionForm,
    DuoExpandedLoggingForm,
  },
  i18n: {
    successMessage: __('Application settings saved successfully.'),
    errorMessage: __(
      'An error occurred while updating your settings. Reload the page to try again.',
    ),
  },
  inject: [
    'disabledDirectConnectionMethod',
    'betaSelfHostedModelsEnabled',
    'toggleBetaModelsPath',
    'canManageSelfHostedModels',
    'aiGatewayUrl',
    'enabledExpandedLogging',
  ],
  props: {
    redirectPath: {
      type: String,
      required: false,
      default: '',
    },
    duoProVisible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isLoading: false,
      disabledConnection: this.disabledDirectConnectionMethod,
      aiModelsEnabled: this.betaSelfHostedModelsEnabled,
      aiGatewayUrlInput: this.aiGatewayUrl,
      expandedLogging: this.enabledExpandedLogging,
    };
  },
  computed: {
    hasFormChanged() {
      return (
        this.disabledConnection !== this.disabledDirectConnectionMethod ||
        this.hasAiModelsFormChanged ||
        this.hasAiGatewayUrlChanged ||
        this.hasExpandedAiLoggingChanged
      );
    },
    hasAiModelsFormChanged() {
      return this.aiModelsEnabled !== this.betaSelfHostedModelsEnabled;
    },
    hasAiGatewayUrlChanged() {
      return this.aiGatewayUrlInput !== this.aiGatewayUrl;
    },
    hasExpandedAiLoggingChanged() {
      return this.expandedLogging !== this.enabledExpandedLogging;
    },
  },
  methods: {
    async updateSettings({ duoAvailability, experimentFeaturesEnabled }) {
      try {
        this.isLoading = true;

        if (this.hasAiGatewayUrlChanged) {
          await this.updateAiGatewayUrl();
        }

        await updateApplicationSettings({
          duo_availability: duoAvailability,
          instance_level_ai_beta_features_enabled: experimentFeaturesEnabled,
          disabled_direct_code_suggestions: this.disabledConnection,
          enabled_expanded_logging: this.expandedLogging,
        });

        if (this.hasAiModelsFormChanged) {
          await this.updateAiModelsSetting();
        }

        visitUrlWithAlerts(this.redirectPath, [
          {
            message: this.$options.i18n.successMessage,
            variant: VARIANT_INFO,
          },
        ]);
      } catch (error) {
        this.onError(error);
      } finally {
        this.isLoading = false;
      }
    },
    async updateAiModelsSetting() {
      await axios
        .post(this.toggleBetaModelsPath)
        .catch((error) => {
          this.onError(error);
        })
        .finally(() => {
          this.isLoading = false;
        });
    },
    async updateAiGatewayUrl() {
      const { data } = await this.$apollo.mutate({
        mutation: updateAiSettingsMutation,
        variables: {
          input: {
            aiGatewayUrl: this.aiGatewayUrlInput,
          },
        },
      });

      if (data) {
        const { errors } = data.duoSettingsUpdate;

        if (errors.length > 0) {
          throw new Error(errors[0]);
        }
      }
    },
    onConnectionFormChange(value) {
      this.disabledConnection = value;
    },
    onAiModelsFormChange(value) {
      this.aiModelsEnabled = value;
    },
    onAiGatewayUrlChange(value) {
      this.aiGatewayUrlInput = value;
    },
    onExpandedLoggingChange(value) {
      this.expandedLogging = value;
    },
    onError(error) {
      createAlert({
        message: this.$options.i18n.errorMessage,
        captureError: true,
        error,
      });
    },
  },
};
</script>
<template>
  <ai-common-settings
    :is-group="false"
    :has-parent-form-changed="hasFormChanged"
    @submit="updateSettings"
  >
    <template #ai-common-settings-bottom>
      <code-suggestions-connection-form v-if="duoProVisible" @change="onConnectionFormChange" />
      <template v-if="canManageSelfHostedModels">
        <ai-models-form @change="onAiModelsFormChange" />
        <duo-expanded-logging-form @change="onExpandedLoggingChange" />
        <ai-gateway-url-input-form @change="onAiGatewayUrlChange" />
      </template>
    </template>
  </ai-common-settings>
</template>
