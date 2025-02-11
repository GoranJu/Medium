<script>
import { GlTooltipDirective, GlSkeletonLoader } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import getBillableMembersCountQuery from 'ee/subscriptions/graphql/queries/billable_members_count.query.graphql';
import { updateSubscriptionPlanApolloCache } from 'ee/usage_quotas/seats/graphql/utils';
import SubscriptionSeatsStatisticsCard from 'ee/usage_quotas/seats/components/subscription_seats_statistics_card.vue';
import StatisticsSeatsCard from 'ee/usage_quotas/seats/components/statistics_seats_card.vue';
import PublicNamespacePlanInfoCard from 'ee/usage_quotas/seats/components/public_namespace_plan_info_card.vue';
import SubscriptionUpgradeInfoCard from './subscription_upgrade_info_card.vue';
import SubscriptionUserList from './subscription_user_list.vue';

export default {
  name: 'SubscriptionSeats',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    PublicNamespacePlanInfoCard,
    SubscriptionSeatsStatisticsCard,
    StatisticsSeatsCard,
    SubscriptionUpgradeInfoCard,
    SubscriptionUserList,
    GlSkeletonLoader,
  },
  apollo: {
    billableMembersCount: {
      query: getBillableMembersCountQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.group.billableMembersCount;
      },
      error() {
        this.receiveBillableMembersListError();
      },
    },
  },
  inject: [
    'fullPath',
    'isPublicNamespace',
    'explorePlansPath',
    'addSeatsHref',
    'hasNoSubscription',
  ],
  data() {
    return {
      billableMembersCount: 0,
    };
  },
  computed: {
    ...mapState([
      'namespaceId',
      'hasError',
      'maxSeatsUsed',
      'seatsOwed',
      'maxFreeNamespaceSeats',
      'hasLimitedFreePlan',
      'activeTrial',
    ]),
    ...mapGetters(['hasFreePlan', 'isLoading']),
    isPublicFreeNamespace() {
      return this.hasFreePlan && this.isPublicNamespace;
    },
    showUpgradeInfoCard() {
      if (!this.hasNoSubscription) {
        return false;
      }
      return this.hasLimitedFreePlan;
    },
    isLoaderShown() {
      return this.isLoading || this.hasError;
    },
  },
  created() {
    /* This will be removed with https://gitlab.com/groups/gitlab-org/-/epics/11942 */
    this.$store.subscribeAction({
      after: (action, state) => {
        if (action.type === 'receiveGitlabSubscriptionSuccess') {
          updateSubscriptionPlanApolloCache(this.$apolloProvider, {
            planCode: state.planCode,
            planName: state.planName,
            subscriptionId: state.namespaceId,
            subscriptionEndDate: state.subscriptionEndDate,
            subscriptionStartDate: state.subscriptionStartDate,
          });
        }
      },
    });
    this.$store.dispatch('fetchInitialData');
  },
  methods: {
    ...mapActions(['receiveBillableMembersListError']),
  },
};
</script>

<template>
  <section>
    <div class="gl-bg-subtle gl-p-5">
      <div
        v-if="isLoaderShown"
        class="gl-grid gl-gap-5 md:gl-grid-cols-2"
        data-testid="skeleton-loader-cards"
      >
        <div class="gl-border gl-rounded-base gl-bg-default gl-p-5">
          <gl-skeleton-loader :height="64">
            <rect width="140" height="30" x="5" y="0" rx="4" />
            <rect width="240" height="10" x="5" y="40" rx="4" />
            <rect width="340" height="10" x="5" y="54" rx="4" />
          </gl-skeleton-loader>
        </div>

        <div class="gl-border gl-rounded-base gl-bg-default gl-p-5">
          <gl-skeleton-loader :height="64">
            <rect width="140" height="30" x="5" y="0" rx="4" />
            <rect width="240" height="10" x="5" y="40" rx="4" />
            <rect width="340" height="10" x="5" y="54" rx="4" />
          </gl-skeleton-loader>
        </div>
      </div>
      <div v-else class="gl-grid gl-gap-5 md:gl-grid-cols-2">
        <subscription-seats-statistics-card :billable-members-count="billableMembersCount" />
        <subscription-upgrade-info-card
          v-if="showUpgradeInfoCard"
          :max-namespace-seats="maxFreeNamespaceSeats"
          :explore-plans-path="explorePlansPath"
          :active-trial="activeTrial"
        />
        <public-namespace-plan-info-card v-else-if="isPublicFreeNamespace" />
        <!-- StatisticsSeatsCard will eventually be replaced. See https://gitlab.com/gitlab-org/gitlab/-/issues/429828 -->
        <statistics-seats-card
          v-else
          :seats-used="maxSeatsUsed"
          :seats-owed="seatsOwed"
          :purchase-button-link="addSeatsHref"
          :namespace-id="namespaceId"
        />
      </div>
    </div>

    <subscription-user-list :has-free-plan="hasFreePlan" />
  </section>
</template>
