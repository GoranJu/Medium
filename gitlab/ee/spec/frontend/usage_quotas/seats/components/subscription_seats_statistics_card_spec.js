import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import SubscriptionSeatsStatisticsCard from 'ee/usage_quotas/seats/components/subscription_seats_statistics_card.vue';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);
Vue.use(Vuex);

describe('SubscriptionSeatsStatisticsCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createMockApolloProvider = (initialApolloData) => {
    const subscriptionPermissionsQueryHandlerMock = jest.fn().mockResolvedValue({
      data: {
        subscription: {
          canAddSeats: true,
          canAddDuoProSeats: false,
          canRenew: false,
          communityPlan: Boolean(initialApolloData.communityPlan),
        },
        userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
      },
    });
    const handlers = [[getSubscriptionPermissionsData, subscriptionPermissionsQueryHandlerMock]];
    const mockCustomersDotClient = createMockClient(handlers);
    return new VueApollo({ clients: { customersDotClient: mockCustomersDotClient } });
  };

  const fakeStore = (initialGetters = {}, initialState = {}) =>
    new Vuex.Store({
      getters: {
        isLoading: () => false,
        hasFreePlan: () => false,
        ...initialGetters,
      },
      state: {
        activeTrial: false,
        hasLimitedFreePlan: false,
        hasError: false,
        maxFreeNamespaceSeats: 5,
        namespaceId: 13,
        seatsInSubscription: 13,
        ...initialState,
      },
    });

  const createWrapper = ({
    initialApolloData = {},
    initialGetters = {},
    initialState = {},
    props = {},
    provide = {},
  } = {}) => {
    const apolloProvider = createMockApolloProvider(initialApolloData);
    wrapper = shallowMountExtended(SubscriptionSeatsStatisticsCard, {
      apolloProvider,
      propsData: {
        billableMembersCount: 3,
        ...props,
      },
      provide: {
        hasNoSubscription: true,
        ...provide,
      },
      store: fakeStore(initialGetters, initialState),
    });
  };

  const findTooltipLink = () => wrapper.findComponent(GlLink);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findUsageStatistics = () => wrapper.findComponent(UsageStatistics);
  const findUnlimitedSeatCountText = () => wrapper.findByText('You have unlimited seat count.');
  const findSeatsInfo = () => wrapper.findByTestId('seats-info');

  describe('when store data is loading', () => {
    it('renders <skeleton-loader> component', async () => {
      const initialGetters = { isLoading: () => true };

      createWrapper({ initialGetters });

      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('when GraphQL data is loading', () => {
    it('renders <skeleton-loader> component', () => {
      createWrapper();

      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('with a free plan', () => {
    beforeEach(() => {
      const initialGetters = { hasFreePlan: () => true };
      createWrapper({ initialGetters });
      return waitForPromises();
    });

    it('passes the correct seats data', () => {
      expect(findUsageStatistics().props()).toMatchObject({
        percentage: null,
        totalValue: 'Unlimited',
        usageValue: '3',
      });
    });

    it('shows correct billing info', () => {
      expect(findUnlimitedSeatCountText().exists()).toBe(true);
    });

    it('shows correct seat info', () => {
      expect(findSeatsInfo().text()).toBe('Free seats used');
    });

    it('renders the tooltip link', () => {
      expect(findTooltipLink().attributes('href')).toBe(
        '/help/subscriptions/gitlab_com/_index#how-seat-usage-is-determined',
      );
    });

    it('has no tooltip text', () => {
      expect(findTooltipLink().attributes('title')).toBeUndefined();
    });
  });

  describe('with a limited free plan', () => {
    beforeEach(() => {
      const initialState = { hasLimitedFreePlan: true };
      createWrapper({ initialState });
      return waitForPromises();
    });

    it('passes the correct seats data', () => {
      expect(findUsageStatistics().props()).toMatchObject({
        percentage: 60,
        totalValue: '5',
        usageValue: '3',
      });
    });

    it('has no billing info', () => {
      expect(findUnlimitedSeatCountText().exists()).toBe(false);
    });

    it('shows correct seat info', () => {
      expect(findSeatsInfo().text()).toBe('Seats in use / Seats available');
    });

    it('renders the tooltip link', () => {
      expect(findTooltipLink().attributes('href')).toBe(
        '/help/subscriptions/gitlab_com/_index#how-seat-usage-is-determined',
      );
    });

    it('has a tooltip text', () => {
      expect(findTooltipLink().attributes('title')).toBe('Free groups are limited to 5 seats.');
    });
  });

  describe('with an active trial', () => {
    beforeEach(() => {
      const initialState = { activeTrial: true, hasLimitedFreePlan: true };
      createWrapper({ initialState });
      return waitForPromises();
    });

    it('passes the correct seats data', () => {
      expect(findUsageStatistics().props()).toMatchObject({
        percentage: null,
        totalValue: 'Unlimited',
        usageValue: '3',
      });
    });

    it('has no billing info', () => {
      expect(findUnlimitedSeatCountText().exists()).toBe(false);
    });

    it('shows correct seat info', () => {
      expect(findSeatsInfo().text()).toBe('Seats in use / Seats available');
    });

    it('renders the tooltip link', () => {
      expect(findTooltipLink().attributes('href')).toBe(
        '/help/subscriptions/gitlab_com/_index#how-seat-usage-is-determined',
      );
    });

    it('has a tooltip text', () => {
      expect(findTooltipLink().attributes('title')).toBe(
        'Free tier and trial groups can invite a maximum of 20 members per day.',
      );
    });
  });

  describe('with a community plan', () => {
    beforeEach(() => {
      const provide = { hasNoSubscription: false };
      const initialApolloData = { communityPlan: true };
      createWrapper({ initialApolloData, provide });
      return waitForPromises();
    });

    it('passes the correct seats data', () => {
      expect(findUsageStatistics().props()).toMatchObject({
        percentage: 23,
        totalValue: '13',
        usageValue: '3',
      });
    });

    it('shows correct billing info', () => {
      expect(findUnlimitedSeatCountText().exists()).toBe(false);
    });

    it('shows correct seat info', () => {
      expect(findSeatsInfo().text()).toBe('Open source Plan Seats used');
    });

    it('renders the tooltip link', () => {
      expect(findTooltipLink().attributes('href')).toBe(`${PROMO_URL}/solutions/open-source/`);
    });

    it('has no tooltip text', () => {
      expect(findTooltipLink().attributes('title')).toBeUndefined();
    });
  });

  describe('with a plan', () => {
    beforeEach(() => {
      const initialGetters = { hasFreePlan: () => false };
      const provide = { hasNoSubscription: false };
      createWrapper({ initialGetters, provide });
      return waitForPromises();
    });

    it('passes the correct seats data', () => {
      expect(findUsageStatistics().props()).toMatchObject({
        percentage: 23,
        totalValue: '13',
        usageValue: '3',
      });
    });

    it('has no billing info', () => {
      expect(findUnlimitedSeatCountText().exists()).toBe(false);
    });

    it('shows correct seat info', () => {
      expect(findSeatsInfo().text()).toBe('Seats in use / Seats in subscription');
    });

    it('renders the tooltip link', () => {
      expect(findTooltipLink().attributes('href')).toBe(
        '/help/subscriptions/gitlab_com/_index#how-seat-usage-is-determined',
      );
    });

    it('has no tooltip text', () => {
      expect(findTooltipLink().attributes('title')).toBeUndefined();
    });
  });
});
