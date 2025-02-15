<script>
import {
  GlCard,
  GlLink,
  GlSprintf,
  GlButton,
  GlSkeletonLoader,
  GlModalDirective,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, __ } from '~/locale';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import {
  DUO_PRO,
  DUO_ENTERPRISE,
  codeSuggestionsLearnMoreLink,
} from 'ee/usage_quotas/code_suggestions/constants';
import { addSeatsText } from 'ee/usage_quotas/seats/constants';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import { InternalEvents } from '~/tracking';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import { visitUrl } from '~/lib/utils/url_utility';
import { LIMITED_ACCESS_KEYS } from 'ee/usage_quotas/components/constants';
import { ADD_ON_PURCHASE_FETCH_ERROR_CODE } from 'ee/usage_quotas/error_constants';
import getGitlabSubscriptionQuery from 'ee/fulfillment/shared_queries/gitlab_subscription.query.graphql';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { PQL_MODAL_ID } from 'ee/hand_raise_leads/hand_raise_lead/constants';

export default {
  name: 'CodeSuggestionsUsageInfoCard',
  helpLinks: {
    codeSuggestionsLearnMoreLink,
  },
  i18n: {
    description: s__(
      `CodeSuggestions|%{linkStart}Code Suggestions%{linkEnd} uses generative AI to suggest code while you're developing.`,
    ),
    subscriptionTitle: s__('CodeSuggestions|Subscription'),
    trialTitle: s__('CodeSuggestions|Trial'),
    addSeatsText,
    startDateText: __('Start date:'),
    endDateText: __('End date:'),
    notAvailable: __('Not available'),
    purchaseSeats: __('Purchase seats'),
    trial: s__('CodeSuggestions|trial'),
  },
  components: {
    GlButton,
    GlCard,
    GlLink,
    GlSprintf,
    UsageStatistics,
    GlSkeletonLoader,
    LimitedAccessModal,
    HandRaiseLeadButton,
  },
  directives: {
    GlModalDirective,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    addDuoProHref: { default: null },
    isSaaS: { default: false },
    subscriptionName: { default: null },
    subscriptionStartDate: { default: null },
    subscriptionEndDate: { default: null },
    duoAddOnIsTrial: { default: null },
    duoAddOnStartDate: { default: null },
    duoAddOnEndDate: { default: null },
  },
  props: {
    groupId: {
      type: Number,
      required: false,
      default: null,
    },
    duoTier: {
      type: String,
      required: false,
      default: DUO_PRO,
      validator: (val) => [DUO_PRO, DUO_ENTERPRISE].includes(val),
    },
  },
  data() {
    return {
      showLimitedAccessModal: false,
    };
  },
  computed: {
    shouldShowCTAButton() {
      return !this.isLoading;
    },
    hasNoRequestInformation() {
      return !(this.groupId || this.subscriptionName);
    },
    isLoading() {
      return this.$apollo.queries.subscriptionPermissions.loading;
    },
    trackingPreffix() {
      return this.isSaaS ? 'saas' : 'sm';
    },
    shouldShowModal() {
      return !this.subscriptionPermissions?.canAddDuoProSeats && this.hasLimitedAccess;
    },
    hasLimitedAccess() {
      return LIMITED_ACCESS_KEYS.includes(this.permissionReason);
    },
    permissionReason() {
      return this.subscriptionPermissions?.reason;
    },
    titleText() {
      return this.duoAddOnIsTrial
        ? this.$options.i18n.trialTitle
        : this.$options.i18n.subscriptionTitle;
    },
    subscriptionEndDateText() {
      return this.duoAddOnIsTrial
        ? this.$options.i18n.trialEndDate
        : this.$options.i18n.subscriptionEndDate;
    },
    startDate() {
      if (this.duoAddOnIsTrial) {
        return this.formattedDate(this.duoAddOnStartDate);
      }

      const date = this.subscription?.startDate || this.subscriptionStartDate;
      return date ? this.formattedDate(date) : this.$options.i18n.notAvailable;
    },
    endDate() {
      if (this.duoAddOnIsTrial) {
        return this.formattedDate(this.duoAddOnEndDate);
      }

      const date = this.subscription?.endDate || this.subscriptionEndDate;
      return date ? this.formattedDate(date) : this.$options.i18n.notAvailable;
    },
    isDuoEnterprise() {
      return this.duoTier === DUO_ENTERPRISE;
    },
    isDuoPro() {
      return this.duoTier === DUO_PRO;
    },
    pageViewLabel() {
      return this.duoAddOnIsTrial
        ? `duo_${this.duoTier}_add_on_tab_active_trial`
        : `duo_${this.duoTier}_add_on_tab`;
    },
    handRaiseLeadBtnTracking() {
      return {
        category: 'groups:usage_quotas:index',
        action: 'click_button',
        label: `duo_${this.duoTier}_contact_sales`,
      };
    },
    trialHandRaiseLeadAttributes() {
      return {
        ...this.$options.sharedHandRaiseLeadAttributes,
        ...{ category: this.isDuoPro ? 'secondary' : 'primary' },
      };
    },
    nonTrialHandRaiseLeadAttributes() {
      return {
        ...this.$options.sharedHandRaiseLeadAttributes,
        ...{ category: 'primary' },
      };
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    subscription: {
      query: getGitlabSubscriptionQuery,
      variables() {
        return {
          namespaceId: this.groupId,
        };
      },
      skip() {
        return !this.groupId;
      },
      error: (error) => {
        Sentry.captureException(error);
      },
    },
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    subscriptionPermissions: {
      query: getSubscriptionPermissionsData,
      client: 'customersDotClient',
      variables() {
        return this.groupId
          ? { namespaceId: this.groupId }
          : { subscriptionName: this.subscriptionName };
      },
      skip() {
        return this.hasNoRequestInformation;
      },
      update: (data) => ({
        canAddDuoProSeats: data.subscription?.canAddDuoProSeats,
        reason: data.userActionAccess?.limitedAccessReason,
      }),
      error(error) {
        const errorWithCause = Object.assign(error, { cause: ADD_ON_PURCHASE_FETCH_ERROR_CODE });
        this.$emit('error', errorWithCause);
        Sentry.captureException(error, {
          tags: {
            vue_component: this.$options.name,
          },
        });
      },
    },
  },
  mounted() {
    this.trackEvent(
      'view_group_duo_usage_pageload',
      {
        label: this.pageViewLabel,
      },
      'groups:usage_quotas:index',
    );
  },
  methods: {
    handleAddDuoProClick() {
      this.trackEvent('click_add_seats_button_group_duo_usage_page', {
        label: `add_duo_${this.duoTier}_${this.trackingPreffix}`,
        property: 'usage_quotas_page',
      });
    },
    handleAddSeats() {
      if (this.shouldShowModal) {
        this.showLimitedAccessModal = true;
        return;
      }

      this.handleAddDuoProClick();
      visitUrl(this.addDuoProHref);
    },
    handlePurchaseSeats() {
      this.trackEvent(
        'click_purchase_seats_button_group_duo_usage_page',
        {
          label: `duo_${this.duoTier}_purchase_seats`,
        },
        'groups:usage_quotas:index',
      );

      visitUrl(this.addDuoProHref);
    },
    handleCodeSuggestionsLink() {
      this.trackEvent(
        'click_marketing_link_group_duo_usage_page',
        {
          label: `duo_${this.duoTier}_marketing_page`,
        },
        'groups:usage_quotas:index',
      );

      visitUrl(this.$options.helpLinks.codeSuggestionsLearnMoreLink);
    },
    formattedDate(date) {
      const [year, month, day] = date.split('-');
      return localeDateFormat.asDate.format(new Date(year, month - 1, day));
    },
  },
  sharedHandRaiseLeadAttributes: {
    size: 'small',
    variant: 'confirm',
  },
  modalId: PQL_MODAL_ID,
};
</script>
<template>
  <gl-card>
    <gl-skeleton-loader v-if="isLoading" :height="64">
      <rect width="140" height="30" x="5" y="0" rx="4" />
      <rect width="240" height="10" x="5" y="40" rx="4" />
      <rect width="340" height="10" x="5" y="54" rx="4" />
    </gl-skeleton-loader>
    <usage-statistics v-else>
      <template #description>
        <h2 class="gl-mb-3 gl-mt-0 gl-text-lg gl-font-bold" data-testid="title">
          {{ sprintf(titleText) }}
        </h2>
      </template>
      <template #additional-info>
        <div data-testid="subscription-info">
          <div class="gl-flex gl-gap-3">
            <span class="gl-font-bold">{{ $options.i18n.startDateText }}</span>
            <span>{{ startDate }}</span>
          </div>
          <div class="gl-mt-2 gl-flex gl-gap-3">
            <span class="gl-font-bold">{{ $options.i18n.endDateText }}</span>
            <span>{{ endDate }}</span>
          </div>
          <p class="gl-mb-0 gl-mt-4 gl-text-subtle" data-testid="description">
            <gl-sprintf :message="$options.i18n.description">
              <template #link="{ content }">
                <gl-link
                  target="_blank"
                  data-testid="usage-quotas-gitlab-duo-tab-code-suggestions-link"
                  @click="handleCodeSuggestionsLink"
                  >{{ content }}</gl-link
                >
              </template>
            </gl-sprintf>
          </p>
        </div>
      </template>
      <template #actions>
        <div v-if="duoAddOnIsTrial">
          <gl-button
            v-if="isDuoPro"
            variant="confirm"
            size="small"
            data-testid="usage-quotas-gitlab-duo-tab-active-trial-purchase-seats-button"
            @click="handlePurchaseSeats"
          >
            {{ $options.i18n.purchaseSeats }}
          </gl-button>

          <hand-raise-lead-button
            :modal-id="$options.modalId"
            :button-attributes="trialHandRaiseLeadAttributes"
            :cta-tracking="handRaiseLeadBtnTracking"
            glm-content="usage-quotas-gitlab-duo-tab"
          />
        </div>
        <div v-else>
          <div v-if="shouldShowCTAButton">
            <hand-raise-lead-button
              v-if="isDuoEnterprise"
              :modal-id="$options.modalId"
              :button-attributes="nonTrialHandRaiseLeadAttributes"
              :cta-tracking="handRaiseLeadBtnTracking"
              glm-content="usage-quotas-gitlab-duo-tab"
            />
            <gl-button
              v-else
              v-gl-modal-directive="'limited-access-modal-id'"
              category="primary"
              target="_blank"
              variant="confirm"
              size="small"
              class="gl-ml-3 gl-self-start"
              data-testid="purchase-button"
              @click="handleAddSeats"
            >
              {{ $options.i18n.addSeatsText }}
            </gl-button>
          </div>
          <limited-access-modal
            v-if="shouldShowModal"
            v-model="showLimitedAccessModal"
            :limited-access-reason="permissionReason"
          />
        </div>
      </template>
    </usage-statistics>
  </gl-card>
</template>
