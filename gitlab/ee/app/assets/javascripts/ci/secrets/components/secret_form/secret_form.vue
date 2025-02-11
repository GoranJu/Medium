<script>
import {
  GlButton,
  GlCollapsibleListbox,
  GlDatepicker,
  GlDropdownDivider,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlLink,
  GlSprintf,
} from '@gitlab/ui';
import { isDate } from 'lodash';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import { getDateInFuture } from '~/lib/utils/datetime_utility';
import CiEnvironmentsDropdown from '~/ci/common/private/ci_environments_dropdown';
import {
  DETAILS_ROUTE_NAME,
  INDEX_ROUTE_NAME,
  ROTATION_PERIOD_OPTIONS,
  SECRET_DESCRIPTION_MAX_LENGTH,
} from '../../constants';
import { convertRotationPeriod } from '../../utils';
import CreateSecretMutation from '../../graphql/mutations/create_secret.mutation.graphql';
import SecretBranchesField from './secret_branches_field.vue';

export default {
  name: 'SecretForm',
  components: {
    CiEnvironmentsDropdown,
    GlButton,
    GlCollapsibleListbox,
    GlDropdownDivider,
    GlDatepicker,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlLink,
    GlSprintf,
    SecretBranchesField,
  },
  props: {
    areEnvironmentsLoading: {
      type: Boolean,
      required: true,
    },
    environments: {
      type: Array,
      required: false,
      default: () => [],
    },
    fullPath: {
      type: String,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      customRotationPeriod: '',
      isSubmitting: false,
      secret: {
        branch: '',
        createdAt: undefined,
        description: '',
        environment: '',
        expiration: undefined,
        name: undefined,
        rotationPeriod: '',
        value: undefined,
      },
    };
  },
  computed: {
    canSubmit() {
      return (
        this.isBranchValid &&
        this.isExpirationValid &&
        this.isNameValid &&
        this.isValueValid &&
        this.isDescriptionValid &&
        this.isEnvironmentScopeValid
      );
    },
    createdAt() {
      return this.secret.createdAt || Date.now();
    },
    isBranchValid() {
      return this.secret.branch.length > 0;
    },
    isDescriptionValid() {
      return this.secret.description.length <= SECRET_DESCRIPTION_MAX_LENGTH;
    },
    isEnvironmentScopeValid() {
      return this.secret.environment.length > 0;
    },
    isExpirationValid() {
      return isDate(this.secret.expiration);
    },
    isNameValid() {
      return this.secret.name.length > 0;
    },
    isValueValid() {
      return this.secret.value.length > 0;
    },
    minExpirationDate() {
      // secrets can expire tomorrow, but not today or yesterday
      const today = new Date();
      return getDateInFuture(today, 1);
    },
    rotationPeriodText() {
      return convertRotationPeriod(this.secret.rotationPeriod);
    },
    rotationPeriodToggleText() {
      if (this.secret.rotationPeriod.length) {
        return this.rotationPeriodText;
      }

      return s__('Secrets|Select a reminder interval');
    },
  },
  methods: {
    async createSecret() {
      this.isSubmitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: CreateSecretMutation,
          variables: {
            projectPath: this.fullPath,
            ...this.secret,
            name: this.secret.name,
          },
        });

        const error = data.projectSecretCreate.errors[0];
        if (error) {
          createAlert({ message: error });
          return;
        }

        this.$router.push({ name: DETAILS_ROUTE_NAME, params: { secretName: this.secret.name } });
      } catch (e) {
        createAlert({ message: __('Something went wrong on our end. Please try again.') });
      } finally {
        this.isSubmitting = false;
      }
    },
    editSecret() {
      // TODO
    },
    setBranch(branch) {
      this.secret.branch = branch;
    },
    setCustomRotationPeriod() {
      this.secret.rotationPeriod = this.customRotationPeriod;
    },
    setEnvironment(environment) {
      this.secret.environment = environment;
    },
    async submitSecret() {
      if (this.isEditing) {
        await this.editSecret();
      } else {
        await this.createSecret();
      }
    },
  },
  datePlaceholder: 'YYYY-MM-DD',
  cronPlaceholder: '0 6 * * *',
  i18n: {
    fieldRequired: __('This field is required'),
  },
  rotationPeriodOptions: ROTATION_PERIOD_OPTIONS,
  secretsIndexRoute: INDEX_ROUTE_NAME,
};
</script>
<template>
  <div>
    <gl-form @submit.prevent="submitSecret">
      <gl-form-group
        data-testid="secret-name-field-group"
        label-for="secret-name"
        :label="__('Name')"
        :description="s__('Secrets|The name should be unique within this project.')"
        :invalid-feedback="$options.i18n.fieldRequired"
        :state="secret.name === undefined || isNameValid"
      >
        <gl-form-input
          id="secret-name"
          v-model="secret.name"
          :placeholder="__('Enter a name')"
          :state="secret.name === undefined || isNameValid"
        />
      </gl-form-group>
      <gl-form-group
        data-testid="secret-value-field-group"
        label-for="secret-value"
        :label="__('Value')"
        :invalid-feedback="$options.i18n.fieldRequired"
      >
        <gl-form-textarea
          id="secret-value"
          v-model="secret.value"
          rows="5"
          max-rows="15"
          no-resize
          :placeholder="s__('Secrets|Enter a value for the secret')"
          :spellcheck="false"
          :state="secret.value === undefined || isValueValid"
        />
      </gl-form-group>
      <gl-form-group
        :label="__('Description')"
        data-testid="secret-description-field-group"
        label-for="secret-description"
        :description="s__('Secrets|Maximum 200 characters.')"
        :invalid-feedback="s__('Secrets|Description must be 200 characters or less.')"
        optional
      >
        <gl-form-input
          id="secret-description"
          v-model.trim="secret.description"
          data-testid="secret-description"
          :placeholder="s__('Secrets|Add a description for the secret')"
          :state="isDescriptionValid"
        />
      </gl-form-group>
      <div class="gl-flex gl-gap-4">
        <gl-form-group
          :label="__('Environments')"
          label-for="secret-environments"
          class="gl-w-1/2 gl-pr-2"
        >
          <ci-environments-dropdown
            id="secret-environments"
            :are-environments-loading="areEnvironmentsLoading"
            :environments="environments"
            :is-environment-required="false"
            :selected-environment-scope="secret.environment"
            @select-environment="setEnvironment"
            @search-environment-scope="$emit('search-environment', $event)"
          />
        </gl-form-group>
        <gl-form-group :label="__('Branches')" label-for="secret-branches" class="gl-w-1/2 gl-pr-2">
          <secret-branches-field
            label-for="secret-branches"
            :full-path="fullPath"
            :selected-branch="secret.branch"
            @select-branch="setBranch"
          />
        </gl-form-group>
      </div>
      <div class="gl-flex gl-gap-4">
        <gl-form-group
          class="gl-w-full"
          label-for="secret-expiration"
          :label="__('Expiration date')"
        >
          <gl-datepicker
            id="secret-expiration"
            v-model="secret.expiration"
            class="gl-max-w-none"
            :placeholder="$options.datePlaceholder"
            :min-date="minExpirationDate"
          />
        </gl-form-group>
        <gl-form-group
          class="gl-w-full"
          :label="s__('Secrets|Rotation period')"
          label-for="secret-rotation-period"
          optional
        >
          <gl-collapsible-listbox
            id="secret-rotation-period"
            v-model.trim="secret.rotationPeriod"
            block
            :label-text="s__('Secrets|Rotation reminder')"
            :header-text="s__('Secrets|Intervals')"
            :toggle-text="rotationPeriodToggleText"
            :items="$options.rotationPeriodOptions"
            optional
          >
            <template #footer>
              <gl-dropdown-divider />
              <div class="gl-mx-3 gl-mb-4 gl-mt-3">
                <p class="gl-my-0 gl-py-0">{{ s__('Secrets|Add custom interval.') }}</p>
                <p class="gl-my-0 gl-py-0 gl-text-sm gl-text-subtle">
                  <gl-sprintf :message="__('Use CRON syntax. %{linkStart}Learn more.%{linkEnd}')">
                    <template #link="{ content }">
                      <gl-link href="https://crontab.guru/" target="_blank">{{ content }}</gl-link>
                    </template>
                  </gl-sprintf>
                </p>
                <gl-form-input
                  v-model="customRotationPeriod"
                  data-testid="secret-cron"
                  :placeholder="$options.cronPlaceholder"
                  class="gl-my-3"
                />
                <gl-button
                  class="gl-float-right"
                  data-testid="add-custom-rotation-button"
                  size="small"
                  variant="confirm"
                  :aria-label="__('Add interval')"
                  @click="setCustomRotationPeriod"
                >
                  {{ __('Add interval') }}
                </gl-button>
              </div>
            </template>
          </gl-collapsible-listbox>
        </gl-form-group>
      </div>
      <div class="gl-my-3">
        <gl-button
          variant="confirm"
          data-testid="submit-form-button"
          :aria-label="s__('Secrets|Add secret')"
          :disabled="!canSubmit || isSubmitting"
          :loading="isSubmitting"
          @click="submitSecret"
        >
          {{ s__('Secrets|Add secret') }}
        </gl-button>
        <gl-button
          :to="{ name: $options.secretsIndexRoute }"
          data-testid="cancel-button"
          class="gl-my-4"
          :aria-label="__('Cancel')"
          :disabled="isSubmitting"
        >
          {{ __('Cancel') }}
        </gl-button>
      </div>
    </gl-form>
  </div>
</template>
