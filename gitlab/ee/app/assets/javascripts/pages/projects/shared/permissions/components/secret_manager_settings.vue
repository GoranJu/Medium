<script>
import { GlToggle } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  ACTION_ENABLE_SECRET_MANAGER,
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_INACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
} from 'ee/ci/secrets/constants';
import enableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';

export const POLL_INTERVAL = 2000;

export default {
  components: {
    GlToggle,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      action: null,
      hasError: false,
      secretManagerStatus: SECRET_MANAGER_STATUS_INACTIVE,
    };
  },
  apollo: {
    secretManagerStatus: {
      query: getSecretManagerStatusQuery,
      variables() {
        return {
          projectPath: this.fullPath,
        };
      },
      update({ projectSecretsManager }) {
        const newStatus = projectSecretsManager?.status || SECRET_MANAGER_STATUS_INACTIVE;

        if (newStatus !== SECRET_MANAGER_STATUS_PROVISIONING) {
          this.$apollo.queries.secretManagerStatus.stopPolling();
        }

        if (this.isEnablingSecretsManager && newStatus === SECRET_MANAGER_STATUS_ACTIVE) {
          this.$toast.show(s__('Secrets|Secrets Manager has been provisioned for this project.'));
        }

        return newStatus;
      },
      error() {
        this.$apollo.queries.secretManagerStatus.stopPolling(POLL_INTERVAL);
        this.hasError = true;

        if (this.isEnablingSecretsManager) {
          this.secretManagerStatus = SECRET_MANAGER_STATUS_INACTIVE;
        }
      },
      pollInterval: POLL_INTERVAL,
    },
  },
  computed: {
    isActive() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_ACTIVE;
    },
    isEnablingSecretsManager() {
      return this.action === ACTION_ENABLE_SECRET_MANAGER;
    },
    isInactive() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_INACTIVE;
    },
    isLoading() {
      return this.$apollo.queries.secretManagerStatus.loading;
    },
    isProvisioning() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_PROVISIONING;
    },
    isToggleDisabled() {
      return this.isLoading || this.isProvisioning || this.isActive;
    },
    isToggleLoading() {
      return this.isLoading || this.isProvisioning;
    },
  },
  methods: {
    async enableProjectSecretsManager() {
      this.hasError = false;
      try {
        const {
          data: {
            projectSecretsManagerInitialize: { errors, projectSecretsManager },
          },
        } = await this.$apollo.mutate({
          mutation: enableSecretManagerMutation,
          variables: {
            projectPath: this.fullPath,
          },
        });

        if (errors.length > 0) {
          throw new Error(errors[0]);
        }

        this.secretManagerStatus = projectSecretsManager?.status || SECRET_MANAGER_STATUS_INACTIVE;
        this.$apollo.queries.secretManagerStatus.startPolling(POLL_INTERVAL);
      } catch (error) {
        this.hasError = true;
      }
    },
    onToggleSecretManager() {
      if (this.isInactive) {
        this.action = ACTION_ENABLE_SECRET_MANAGER;
        this.enableProjectSecretsManager();
      }
    },
  },
};
</script>

<template>
  <div data-testid="secret-manager">
    <label class="gl-mb-1 gl-mr-3">
      {{ s__('Secrets|Secrets Manager') }}
    </label>
    <p class="gl-mb-2">
      {{
        s__(
          'Secrets|Enable the Secrets Manager to securely store and manage sensitive information for this project.',
        )
      }}
    </p>
    <gl-toggle
      :value="isActive"
      :label="s__('Secrets|Secrets Manager')"
      :disabled="isToggleDisabled"
      :is-loading="isToggleLoading"
      label-position="hidden"
      name="secret_manager_enabled"
      data-testid="secret-manager-toggle"
      @change="onToggleSecretManager"
    />
    <p v-if="hasError" class="gl-mt-2 gl-text-red-500" data-testid="secret-manager-error">
      {{ __('Something went wrong. Please try again.') }}
    </p>
  </div>
</template>
