<script>
// eslint-disable-next-line no-restricted-imports
import { mapGetters, mapState } from 'vuex';
import { GlLink, GlTooltipDirective, GlSkeletonLoader } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import { __, s__, sprintf } from '~/locale';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import { seatsInUseLink } from 'ee/usage_quotas/seats/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

export default {
  name: 'SubscriptionSeatsStatisticsCard',
  components: { GlLink, GlSkeletonLoader, UsageStatistics, HelpIcon },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['hasNoSubscription'],
  props: {
    billableMembersCount: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  data() {
    return {
      communityPlan: false,
    };
  },
  apollo: {
    communityPlan: {
      query: getSubscriptionPermissionsData,
      client: 'customersDotClient',
      variables() {
        return {
          namespaceId: this.namespaceId,
        };
      },
      update: (data) => Boolean(data.subscription?.communityPlan),
      error: (error) => {
        const { networkError } = error;
        networkError?.result?.errors.forEach(({ message }) => Sentry.captureException(message));
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    ...mapGetters(['hasFreePlan', 'isLoading']),
    ...mapState([
      'activeTrial',
      'hasLimitedFreePlan',
      'maxFreeNamespaceSeats',
      'namespaceId',
      'seatsInSubscription',
    ]),
    freeNamespaceSeatsLimitText() {
      return sprintf(s__('Billings|Free groups are limited to %{number} seats.'), {
        number: this.maxFreeNamespaceSeats,
      });
    },
    hasNoSeatsInSubscription() {
      return this.totalSeatsUsed == null;
    },
    isDataLoading() {
      return this.isLoading || this.$apollo.loading;
    },
    percentage() {
      if (this.hasFreePlan || this.hasNoSeatsInSubscription || this.activeTrial) {
        return null;
      }
      return Math.round((this.billableMembersCount * 100) / this.totalSeatsUsed);
    },
    seatsStatisticsText() {
      if (this.communityPlan) return s__('Billings|Open source Plan Seats used');
      if (this.hasFreePlan) return s__('Billings|Free seats used');
      if (this.hasLimitedFreePlan) return s__('Billings|Seats in use / Seats available');
      return s__('Billings|Seats in use / Seats in subscription');
    },
    shouldDisplayUnlimitedSeatText() {
      return this.hasFreePlan;
    },
    totalSeatsUsed() {
      if (this.hasNoSubscription) {
        return this.hasLimitedFreePlan ? this.maxFreeNamespaceSeats : null;
      }
      return this.seatsInSubscription;
    },
    totalSeatsUsedToDisplay() {
      const unlimited = __('Unlimited');

      if (this.activeTrial) return unlimited;

      return this.totalSeatsUsed ? String(this.totalSeatsUsed) : unlimited;
    },
    tooltipLink() {
      if (this.communityPlan) return `${PROMO_URL}/solutions/open-source/`;

      return seatsInUseLink;
    },
    tooltipText() {
      if (this.communityPlan) return null;
      if (!this.hasLimitedFreePlan) return null;
      if (this.activeTrial)
        return s__(
          'Billings|Free tier and trial groups can invite a maximum of 20 members per day.',
        );
      return this.freeNamespaceSeatsLimitText;
    },
  },
};
</script>

<template>
  <div
    class="gl-border gl-rounded-base gl-border-section gl-bg-section gl-p-5"
    data-testid="container"
  >
    <div v-if="isDataLoading">
      <gl-skeleton-loader :height="64">
        <rect width="140" height="30" x="5" y="0" rx="4" />
        <rect width="240" height="10" x="5" y="40" rx="4" />
        <rect width="340" height="10" x="5" y="54" rx="4" />
      </gl-skeleton-loader>
    </div>
    <template v-else>
      <usage-statistics
        :percentage="percentage"
        :total-value="totalSeatsUsedToDisplay"
        :usage-value="String(billableMembersCount)"
      >
        <template #additional-info>
          <p v-if="seatsStatisticsText" class="gl-mb-0 gl-font-bold" data-testid="seats-info">
            {{ seatsStatisticsText }}
            <gl-link
              v-if="tooltipLink"
              v-gl-tooltip
              :href="tooltipLink"
              target="_blank"
              class="gl-ml-2"
              :title="tooltipText"
              :aria-label="tooltipText"
            >
              <help-icon />
            </gl-link>
          </p>
          <p v-if="shouldDisplayUnlimitedSeatText" class="border-top pt-3 gl-mt-5">
            {{ s__('Billings|You have unlimited seat count.') }}
          </p>
        </template>
      </usage-statistics>
    </template>
  </div>
</template>
