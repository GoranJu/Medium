<script>
import { isBoolean } from 'lodash';
import { GlBadge, GlAlert, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { isInFuture } from '~/lib/utils/datetime/date_calculation_utility';
import getAddOnPurchasesQuery from 'ee/usage_quotas/add_on/graphql/get_add_on_purchases.query.graphql';
import getCurrentLicense from 'ee/admin/subscriptions/show/graphql/queries/get_current_license.query.graphql';

import {
  ADD_ON_CODE_SUGGESTIONS,
  ADD_ON_DUO_ENTERPRISE,
  DUO_ENTERPRISE,
  DUO_PRO,
  DUO_ENTERPRISE_TITLE,
  CODE_SUGGESTIONS_TITLE,
} from 'ee/usage_quotas/code_suggestions/constants';

import {
  currentSubscriptionsEntryName,
  subscriptionHistoryFailedTitle,
  subscriptionHistoryFailedMessage,
  subscriptionActivationFutureDatedNotificationTitle,
  SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT,
} from 'ee/admin/subscriptions/show/constants';

import SaasAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/saas_add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import {
  ADD_ON_ERROR_DICTIONARY,
  ADD_ON_PURCHASE_FETCH_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';
import ErrorAlert from 'ee/vue_shared/components/error_alert/error_alert.vue';
import CodeSuggestionsIntro from './code_suggestions_intro.vue';
import CodeSuggestionsInfoCard from './code_suggestions_info_card.vue';
import CodeSuggestionsStatisticsCard from './code_suggestions_usage_statistics_card.vue';
import CodeSuggestionsUsageLoader from './code_suggestions_usage_loader.vue';

export default {
  name: 'CodeSuggestionsUsage',
  components: {
    ErrorAlert,
    SaasAddOnEligibleUserList,
    SelfManagedAddOnEligibleUserList,
    CodeSuggestionsInfoCard,
    CodeSuggestionsIntro,
    CodeSuggestionsStatisticsCard,
    CodeSuggestionsUsageLoader,
    GlBadge,
    GlAlert,
    GlSprintf,
    PageHeading,
  },
  inject: {
    isSaaS: {},
    isStandalonePage: { default: false },
    groupId: { default: null },
    duoPagePath: { default: null },
  },
  addOnErrorDictionary: ADD_ON_ERROR_DICTIONARY,
  i18n: {
    currentSubscriptionsEntryName,
    subscriptionHistoryFailedTitle,
    subscriptionHistoryFailedMessage,
    subscriptionActivationFutureDatedNotificationTitle,
    codeSuggestionTitle: s__('UsageQuota|Seat utilization'),
    subscriptionActivationNotificationText: s__(
      'CodeSuggestions|Your subscription was successfully activated.',
    ),
    subscriptionActivationFutureDatedNotificationMessage: s__(
      'CodeSuggestions|You have successfully added a license that activates on %{date}.',
    ),
    movedUsageAlertTitle: s__('AiPowered|Seat assignment for GitLab Duo has moved'),
    movedUsageAlertDescription: s__(
      'AiPowered|GitLab Duo seat assignment is now located in GitLab Duo settings.',
    ),
    movedUsageAlertButtonText: s__('AiPowered|View GitLab Duo settings'),
  },
  props: {
    title: {
      type: String,
      required: false,
      default: s__('UsageQuota|Seat utilization'),
    },
    subtitle: {
      type: String,
      required: false,
      default: null,
    },
    forceHideTitle: {
      type: Boolean,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      addOnPurchase: undefined,
      addOnPurchaseFetchError: undefined,
      currentSubscription: {},
      activationNotification: null,
      subscriptionFetchError: null,
    };
  },
  computed: {
    queryVariables() {
      return {
        namespaceId: this.groupGraphQLId,
      };
    },
    groupGraphQLId() {
      return this.groupId ? convertToGraphQLId(TYPENAME_GROUP, this.groupId) : null;
    },
    totalValue() {
      return this.addOnPurchase?.purchasedQuantity ?? 0;
    },
    usageValue() {
      return this.addOnPurchase?.assignedQuantity ?? 0;
    },
    hasCodeSuggestions() {
      return this.totalValue > 0 && this.usageValue >= 0;
    },
    isLoading() {
      return (
        this.$apollo.queries.addOnPurchase.loading ||
        this.$apollo.queries.currentSubscription.loading
      );
    },
    duoTier() {
      return this.addOnPurchase?.name === ADD_ON_DUO_ENTERPRISE ? DUO_ENTERPRISE : DUO_PRO;
    },
    shouldForceHideTitle() {
      if (isBoolean(this.forceHideTitle)) {
        return this.forceHideTitle;
      }

      return this.isSaaS && !this.isStandalonePage;
    },
    showTitleAndSubtitle() {
      if (this.shouldForceHideTitle) {
        return false;
      }
      return !this.isLoading && (this.hasCodeSuggestions || this.addOnPurchaseFetchError);
    },
    subtitleText() {
      if (this.subtitle) {
        return this.subtitle;
      }

      const message = this.isSaaS
        ? s__('CodeSuggestions|Manage seat assignments for %{addOnName} within your group.')
        : s__('CodeSuggestions|Manage seat assignments for %{addOnName}.');
      return sprintf(message, { addOnName: this.codeSuggestionsFriendlyName });
    },
    codeSuggestionsFriendlyName() {
      return this.duoTier === DUO_ENTERPRISE ? DUO_ENTERPRISE_TITLE : CODE_SUGGESTIONS_TITLE;
    },
    activationListeners() {
      return {
        [SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT]: this.displayActivationNotification,
      };
    },
  },
  apollo: {
    addOnPurchase: {
      query: getAddOnPurchasesQuery,
      variables() {
        return this.queryVariables;
      },
      update({ addOnPurchases }) {
        return (
          // Prioritize Duo Enterprise add-on over Duo Pro if both are available to the namespace.
          // For example, a namespace can have a Duo Pro add-on but also a Duo Enterprise trial add-on.
          addOnPurchases?.find((addOnPurchase) => addOnPurchase.name === ADD_ON_DUO_ENTERPRISE) ||
          addOnPurchases?.find((addOnPurchase) => addOnPurchase.name === ADD_ON_CODE_SUGGESTIONS)
        );
      },
      error(error) {
        const errorWithCause = Object.assign(error, { cause: ADD_ON_PURCHASE_FETCH_ERROR_CODE });
        this.handleAddOnPurchaseFetchError(errorWithCause);
        this.reportError(error);
      },
    },
    currentSubscription: {
      query: getCurrentLicense,
      skip() {
        return this.isSaaS;
      },
      update({ currentLicense }) {
        return currentLicense || {};
      },
      error() {
        this.subscriptionFetchError = currentSubscriptionsEntryName;
      },
    },
  },
  methods: {
    handleAddOnPurchaseFetchError(error) {
      this.addOnPurchaseFetchError = error;
    },
    reportError(error) {
      Sentry.captureException(error, {
        tags: {
          vue_component: this.$options.name,
        },
      });
    },
    createFutureDatedNotification(startsAt) {
      this.activationNotification = {
        title: this.$options.i18n.subscriptionActivationFutureDatedNotificationTitle,
        message: sprintf(this.$options.i18n.subscriptionActivationFutureDatedNotificationMessage, {
          date: startsAt,
        }),
      };
    },
    displayActivationNotification(license) {
      if (isInFuture(new Date(license.startsAt))) {
        this.createFutureDatedNotification(license.startsAt);
      } else {
        this.activationNotification = {
          title: this.$options.i18n.subscriptionActivationNotificationText,
        };
      }

      this.$apollo.queries.addOnPurchase.refetch();
      this.$apollo.queries.currentSubscription.refetch();
    },
    dismissActivationNotification() {
      this.activationNotification = null;
    },
    dismissSubscriptionFetchError() {
      this.subscriptionFetchError = null;
    },
  },
};
</script>

<template>
  <section>
    <code-suggestions-usage-loader v-if="isLoading" />
    <template v-else>
      <gl-alert
        v-if="activationNotification"
        variant="success"
        :title="activationNotification.title"
        class="gl-mb-6"
        data-testid="subscription-activation-success-alert"
        @dismiss="dismissActivationNotification"
      >
        {{ activationNotification.message }}
      </gl-alert>

      <gl-alert
        v-if="subscriptionFetchError"
        :title="$options.i18n.subscriptionHistoryFailedTitle"
        variant="danger"
        class="gl-mb-6"
        data-testid="subscription-fetch-error-alert"
        @dismiss="dismissSubscriptionFetchError"
      >
        <gl-sprintf :message="$options.i18n.subscriptionHistoryFailedMessage">
          <template #subscriptionEntryName>
            {{ subscriptionFetchError }}
          </template>
        </gl-sprintf>
      </gl-alert>

      <template v-if="showTitleAndSubtitle">
        <page-heading>
          <template #heading>
            <span class="gl-flex gl-items-center gl-gap-3">
              <span data-testid="code-suggestions-title">{{ title }}</span>
              <gl-badge variant="tier" icon="license" class="gl-capitalize">{{ duoTier }}</gl-badge>
            </span>
          </template>

          <template #description>
            <span data-testid="code-suggestions-subtitle">
              {{ subtitleText }}
            </span>
          </template>
        </page-heading>

        <slot name="health-check"></slot>
      </template>

      <section v-if="hasCodeSuggestions">
        <slot name="duo-card" v-bind="{ totalValue, usageValue, duoTier }">
          <template v-if="isSaaS && !isStandalonePage && duoPagePath">
            <gl-alert
              variant="info"
              :title="$options.i18n.movedUsageAlertTitle"
              :dismissible="false"
              :primary-button-text="$options.i18n.movedUsageAlertButtonText"
              :primary-button-link="duoPagePath"
              class="gl-mb-5"
              data-testid="duo-moved-usage-alert"
            >
              {{ $options.i18n.movedUsageAlertDescription }}
            </gl-alert>
          </template>
          <template v-else>
            <section class="gl-grid gl-gap-5 md:gl-grid-cols-2">
              <code-suggestions-statistics-card
                :total-value="totalValue"
                :usage-value="usageValue"
                :duo-tier="duoTier"
              />
              <code-suggestions-info-card
                :group-id="groupId"
                :duo-tier="duoTier"
                @error="handleAddOnPurchaseFetchError"
              />
            </section>
            <saas-add-on-eligible-user-list
              v-if="isSaaS"
              :add-on-purchase-id="addOnPurchase.id"
              :duo-tier="duoTier"
            />
            <self-managed-add-on-eligible-user-list
              v-else
              :add-on-purchase-id="addOnPurchase.id"
              :duo-tier="duoTier"
            />
          </template>
        </slot>
      </section>
      <error-alert
        v-else-if="addOnPurchaseFetchError"
        data-testid="add-on-purchase-fetch-error"
        :error="addOnPurchaseFetchError"
        :error-dictionary="$options.addOnErrorDictionary"
        class="gl-mt-5"
      />
      <code-suggestions-intro
        v-else
        :subscription="currentSubscription"
        v-on="activationListeners"
      />
    </template>
  </section>
</template>
