<script>
import { GlForm, GlButton, GlFormGroup, GlFormInput, GlFormSelect } from '@gitlab/ui';
import {
  LEADS_COMPANY_NAME_LABEL,
  LEADS_COMPANY_SIZE_LABEL,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
  LEADS_PHONE_NUMBER_LABEL,
  companySizes,
} from 'ee/vue_shared/leads/constants';
import csrf from '~/lib/utils/csrf';
import { __ } from '~/locale';
import FormErrorTracker from '~/pages/shared/form_error_tracker';
import CountryOrRegionSelector from 'ee/trials/components/country_or_region_selector.vue';
import {
  TRIAL_COMPANY_SIZE_PROMPT,
  TRIAL_PHONE_DESCRIPTION,
  GENERIC_TRIAL_FORM_SUBMIT_TEXT,
  ULTIMATE_TRIAL_FOOTER_DESCRIPTION,
  TRIAL_DESCRIPTION,
  TRIAL_REGISTRATION_DESCRIPTION,
  ULTIMATE_TRIAL_FORM_SUBMIT_TEXT,
} from 'ee/trials/constants';
import { trackCompanyForm } from 'ee/google_tag_manager';

export default {
  csrf,
  components: {
    GlForm,
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    CountryOrRegionSelector,
  },
  inject: {
    user: {
      default: {},
    },
    submitPath: {
      type: String,
      default: '',
    },
    formType: {
      type: String,
    },
    trackActionForErrors: {
      type: String,
      required: false,
    },
  },
  data() {
    return {
      ...this.user,
      companyName: '',
      companySize: null,
      phoneNumber: null,
      country: '',
      state: '',
      websiteUrl: '',
    };
  },
  computed: {
    companySizeOptionsWithDefault() {
      return [
        {
          name: this.$options.i18n.companySizeSelectPrompt,
          id: null,
        },
        ...companySizes,
      ];
    },
  },
  mounted() {
    new FormErrorTracker(); // eslint-disable-line no-new
  },
  methods: {
    trackCompanyForm() {
      trackCompanyForm('ultimate_trial', this.user.emailDomain);
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    companySizeLabel: LEADS_COMPANY_SIZE_LABEL,
    companySizeSelectPrompt: TRIAL_COMPANY_SIZE_PROMPT,
    phoneNumberLabel: LEADS_PHONE_NUMBER_LABEL,
    phoneNumberDescription: TRIAL_PHONE_DESCRIPTION,
    optional: __('(optional)'),
    websiteLabel: __('Website'),
    description: {
      trial: TRIAL_DESCRIPTION,
      registration: TRIAL_REGISTRATION_DESCRIPTION,
    },
    formSubmitText: {
      trial: GENERIC_TRIAL_FORM_SUBMIT_TEXT,
      registration: ULTIMATE_TRIAL_FORM_SUBMIT_TEXT,
    },
    footerDescriptionRegistration: {
      trial: '',
      registration: ULTIMATE_TRIAL_FOOTER_DESCRIPTION,
    },
  },
};
</script>

<template>
  <gl-form
    :action="submitPath"
    class="gl-show-field-errors"
    method="post"
    @submit="trackCompanyForm"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
    <p data-testid="description" class="gl-mt-2">{{ $options.i18n.description[formType] }}</p>
    <div class="gl-mt-6 gl-flex gl-flex-col sm:gl-flex-row">
      <gl-form-group
        :label="$options.i18n.firstNameLabel"
        label-size="sm"
        label-for="first_name"
        class="gl-mr-5 gl-w-full sm:gl-w-1/2"
      >
        <gl-form-input
          id="first_name"
          :value="firstName"
          name="first_name"
          class="js-track-error"
          data-testid="first_name"
          :data-track-action-for-errors="trackActionForErrors"
          required
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.lastNameLabel"
        label-size="sm"
        label-for="last_name"
        class="gl-w-full sm:gl-w-1/2"
      >
        <gl-form-input
          id="last_name"
          :value="lastName"
          name="last_name"
          class="js-track-error"
          data-testid="last_name"
          :data-track-action-for-errors="trackActionForErrors"
          required
        />
      </gl-form-group>
    </div>
    <gl-form-group :label="$options.i18n.companyNameLabel" label-size="sm" label-for="company_name">
      <gl-form-input
        id="company_name"
        :value="companyName"
        name="company_name"
        class="js-track-error"
        data-testid="company_name"
        :data-track-action-for-errors="trackActionForErrors"
        required
      />
    </gl-form-group>
    <gl-form-group :label="$options.i18n.companySizeLabel" label-size="sm" label-for="company_size">
      <gl-form-select
        id="company_size"
        class="gl-field-error-anchor"
        :value="companySize"
        name="company_size"
        select-class="js-track-error"
        :options="companySizeOptionsWithDefault"
        value-field="id"
        text-field="name"
        data-testid="company_size"
        :data-track-action-for-errors="trackActionForErrors"
        required
      />
    </gl-form-group>

    <country-or-region-selector
      :country="country"
      :state="state"
      data-testid="country"
      :track-action-for-errors="trackActionForErrors"
      required
    />

    <gl-form-group
      :label="$options.i18n.phoneNumberLabel"
      :optional-text="$options.i18n.optional"
      label-size="sm"
      :description="$options.i18n.phoneNumberDescription"
      label-for="phone_number"
      optional
    >
      <gl-form-input
        id="phone_number"
        :value="phoneNumber"
        name="phone_number"
        type="tel"
        data-testid="phone_number"
        pattern="^(\+)*[0-9\-\s]+$"
      />
    </gl-form-group>
    <gl-form-group
      :label="$options.i18n.websiteLabel"
      :optional-text="$options.i18n.optional"
      label-size="sm"
      label-for="website_url"
      optional
    >
      <gl-form-input
        id="website_url"
        :value="websiteUrl"
        name="website_url"
        data-testid="website_url"
      />
    </gl-form-group>
    <gl-button type="submit" variant="confirm" class="gl-w-full">
      {{ $options.i18n.formSubmitText[formType] }}
    </gl-button>
    <p data-testid="footer_description_text" class="gl-mt-3 gl-text-sm gl-text-subtle">
      {{ $options.i18n.footerDescriptionRegistration[formType] }}
    </p>
  </gl-form>
</template>
