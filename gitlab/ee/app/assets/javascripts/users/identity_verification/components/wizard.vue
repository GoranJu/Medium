<script>
import { GlLoadingIcon, GlButton } from '@gitlab/ui';
import { kebabCase } from 'lodash';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import { __, s__, sprintf } from '~/locale';
import { convertArrayToCamelCase, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { I18N_GENERIC_ERROR } from '../constants';
import EmailVerification from './email_verification.vue';
import CreditCardVerification from './credit_card_verification.vue';
import PhoneVerification from './phone_verification.vue';
import VerificationStep from './verification_step.vue';

export default {
  name: 'IdentityVerificationWizard',
  components: {
    CreditCardVerification,
    PhoneVerification,
    EmailVerification,
    VerificationStep,
    GlLoadingIcon,
    GlButton,
  },
  inject: ['verificationStatePath', 'phoneExemptionPath', 'successfulVerificationPath'],
  props: {
    username: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      steps: [],
      stepsVerifiedState: {},
      stepsRequiringChallenge: [],
      loading: true,
    };
  },
  computed: {
    activeStep() {
      const isIncomplete = (step) => !this.stepsVerifiedState[step];
      return this.orderedSteps.find(isIncomplete);
    },
    orderedSteps() {
      return [...this.steps].sort(
        (a, b) => this.stepsVerifiedState[b] - this.stepsVerifiedState[a],
      );
    },
    allStepsCompleted() {
      return !Object.entries(this.stepsVerifiedState).filter(([, completed]) => !completed).length;
    },
    pageDescription() {
      return sprintf(this.$options.i18n.pageDescription, {
        username: this.username,
      });
    },
  },
  mounted() {
    this.fetchVerificationState();
  },
  methods: {
    async fetchVerificationState() {
      this.loading = true;
      try {
        // Always fetch a fresh copy of the the user's identity verification
        // state. This avoids stale data, for example, when the user completes
        // the process, gets redirected to the success page and then uses the
        // browser's back button.
        const url = mergeUrlParams({ no_cache: 1 }, this.verificationStatePath);
        const { data } = await axios.get(url);
        this.setVerificationState(data);
      } catch (error) {
        createAlert({
          message: I18N_GENERIC_ERROR,
          captureError: true,
          error,
        });
      } finally {
        this.loading = false;
      }
    },
    setVerificationState({
      verification_methods,
      verification_state,
      methods_requiring_arkose_challenge: methodsRequiringChallenge,
    }) {
      this.steps = convertArrayToCamelCase(verification_methods);
      this.stepsVerifiedState = convertObjectPropsToCamelCase(verification_state);
      this.stepsRequiringChallenge = convertArrayToCamelCase(methodsRequiringChallenge || []);
    },
    onStepCompleted(step) {
      this.stepsVerifiedState[step] = true;
    },
    methodComponent(method) {
      // eslint-disable-next-line @gitlab/require-i18n-strings
      return `${kebabCase(method)}-verification`;
    },
    challengeRequired(method) {
      return this.stepsRequiringChallenge.includes(method);
    },
    stepTitle(step, number) {
      const { ccStep, phoneStep, emailStep } = this.$options.i18n;
      const templates = {
        creditCard: ccStep,
        phone: phoneStep,
        email: emailStep,
      };
      return sprintf(templates[step], { stepNumber: number });
    },
    exemptionRequested() {
      axios
        .patch(this.phoneExemptionPath)
        .then((response) => {
          this.setVerificationState(response.data);
        })
        .catch((error) => {
          createAlert({
            message: I18N_GENERIC_ERROR,
            captureError: true,
            error,
          });
        });
    },
  },
  i18n: {
    pageTitle: s__('IdentityVerification|Help us keep GitLab secure'),
    pageDescription: s__(
      "IdentityVerification|You are signed in as %{username}. For added security, you'll need to verify your identity in a few quick steps.",
    ),
    ccStep: s__('IdentityVerification|Step %{stepNumber}: Verify a payment method'),
    phoneStep: s__('IdentityVerification|Step %{stepNumber}: Verify phone number'),
    emailStep: s__('IdentityVerification|Step %{stepNumber}: Verify email address'),
    next: __('Next'),
  },
};
</script>
<template>
  <div class="gl-flex gl-items-center gl-justify-center">
    <div class="gl-max-w-62 gl-grow">
      <header class="gl-text-center">
        <h2>{{ $options.i18n.pageTitle }}</h2>
        <p>{{ pageDescription }}</p>
      </header>

      <gl-loading-icon v-if="loading" />
      <template v-for="(step, index) in orderedSteps" v-else>
        <verification-step
          :key="step"
          :title="stepTitle(step, index + 1)"
          :completed="stepsVerifiedState[step]"
          :is-active="step === activeStep"
        >
          <component
            :is="methodComponent(step)"
            :require-challenge="challengeRequired(step)"
            @completed="onStepCompleted(step)"
            @exemptionRequested="exemptionRequested"
            @set-verification-state="setVerificationState"
          />
        </verification-step>
      </template>
      <gl-button
        v-if="allStepsCompleted"
        :href="successfulVerificationPath"
        block
        variant="confirm"
      >
        {{ $options.i18n.next }}
      </gl-button>
    </div>
  </div>
</template>
