import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import getBillableMembersCountQuery from 'ee/subscriptions/graphql/queries/billable_members_count.query.graphql';
import SubscriptionSeatsStatisticsCard from 'ee/usage_quotas/seats/components/subscription_seats_statistics_card.vue';
import PublicNamespacePlanInfoCard from 'ee/usage_quotas/seats/components/public_namespace_plan_info_card.vue';
import StatisticsSeatsCard from 'ee/usage_quotas/seats/components/statistics_seats_card.vue';
import SubscriptionUpgradeInfoCard from 'ee/usage_quotas/seats/components/subscription_upgrade_info_card.vue';
import SubscriptionSeats from 'ee/usage_quotas/seats/components/subscription_seats.vue';
import SubscriptionUserList from 'ee/usage_quotas/seats/components/subscription_user_list.vue';
import { mockDataSeats, mockTableItems } from 'ee_jest/usage_quotas/seats/mock_data';
import createMockApolloProvider from 'helpers/mock_apollo_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(Vuex);

const actionSpies = {
  fetchInitialData: jest.fn(),
};

const providedFields = {
  maxFreeNamespaceSeats: 5,
  explorePlansPath: '/groups/test_group/-/billings',
  hasNoSubscription: false,
  hasLimitedFreePlan: false,
  activeTrial: false,
  addSeatsHref: '/groups/test_group/-/seat_usage.csv',
};

const fakeStore = ({ initialState, initialGetters }) =>
  new Vuex.Store({
    actions: actionSpies,
    getters: {
      tableItems: () => mockTableItems,
      isLoading: () => false,
      hasFreePlan: () => false,
      ...initialGetters,
    },
    state: {
      hasError: false,
      namespaceId: 1,
      members: [...mockDataSeats.data],
      total: 300,
      page: 1,
      perPage: 5,
      sort: 'last_activity_on_desc',
      ...providedFields,
      ...initialState,
    },
  });

Vue.use(VueApollo);

describe('Subscription Seats', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const fullPath = 'group-path';
  const { explorePlansPath, addSeatsHref } = providedFields;

  const defaultBillableMembersCountMockHandler = jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 'gid://gitlab/Group/13',
        billableMembersCount: 2,
        enforceFreeUserCap: false,
      },
    },
  });

  const defaultInitialState = {
    total: 2,
    maxSeatsUsed: 3,
    seatsOwed: 1,
  };

  const createComponent = ({ initialState = {}, initialGetters = {}, provide = {} } = {}) => {
    const { isPublicNamespace = false } = initialState;

    const handlers = [[getBillableMembersCountQuery, defaultBillableMembersCountMockHandler]];
    const apolloProvider = createMockApolloProvider(handlers);

    wrapper = extendedWrapper(
      shallowMount(SubscriptionSeats, {
        store: fakeStore({ initialState, initialGetters }),
        apolloProvider,
        provide: {
          fullPath,
          isPublicNamespace,
          explorePlansPath,
          addSeatsHref,
          hasNoSubscription: null,
          ...provide,
        },
      }),
    );

    return waitForPromises();
  };

  const findPublicNamespacePlanInfoCard = () => wrapper.findComponent(PublicNamespacePlanInfoCard);
  const findSubscriptionSeatsStatisticsCard = () =>
    wrapper.findComponent(SubscriptionSeatsStatisticsCard);
  const findStatisticsSeatsCard = () => wrapper.findComponent(StatisticsSeatsCard);
  const findSubscriptionUpgradeCard = () => wrapper.findComponent(SubscriptionUpgradeInfoCard);
  const findSkeletonLoaderCards = () => wrapper.findByTestId('skeleton-loader-cards');
  const findSubscriptionUserList = () => wrapper.findComponent(SubscriptionUserList);

  describe('actions', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('dispatches fetchInitialData action', () => {
      expect(actionSpies.fetchInitialData).toHaveBeenCalled();
    });
  });

  describe('when is a public namespace', () => {
    beforeEach(() => {
      return createComponent({
        initialState: {
          ...defaultInitialState,
          hasLimitedFreePlan: false,
          activeTrial: false,
          isPublicNamespace: true,
        },
        initialGetters: {
          hasFreePlan: () => true,
        },
        provide: {
          hasNoSubscription: true,
        },
      });
    });

    it('renders <public-namespace-plan-info-card>', () => {
      expect(findPublicNamespacePlanInfoCard().exists()).toBe(true);
    });
  });

  describe('statistics', () => {
    beforeEach(() => {
      return createComponent({ initialState: defaultInitialState });
    });

    it('renders <subscription-seats-statistics-card> with the necessary props', () => {
      expect(findSubscriptionSeatsStatisticsCard().props()).toMatchObject({
        billableMembersCount: 2,
      });
    });

    it('renders <statistics-seats-card> with the necessary props', () => {
      const statisticsSeatsCard = findStatisticsSeatsCard();

      expect(findSubscriptionUpgradeCard().exists()).toBe(false);
      expect(statisticsSeatsCard.exists()).toBe(true);
      expect(statisticsSeatsCard.props()).toMatchObject({
        seatsOwed: 1,
        seatsUsed: 3,
      });
    });

    describe('for free namespace with limit', () => {
      beforeEach(() => {
        return createComponent({
          initialState: { hasLimitedFreePlan: true },
          provide: {
            hasNoSubscription: true,
          },
        });
      });

      it('renders <subscription-upgrade-info-card> with the necessary props', () => {
        const upgradeInfoCard = findSubscriptionUpgradeCard();

        expect(findStatisticsSeatsCard().exists()).toBe(false);
        expect(upgradeInfoCard.exists()).toBe(true);
        expect(upgradeInfoCard.props()).toMatchObject({
          maxNamespaceSeats: providedFields.maxFreeNamespaceSeats,
          explorePlansPath: providedFields.explorePlansPath,
          activeTrial: false,
        });
      });
    });
  });

  describe('Loading state', () => {
    describe.each([
      [true, false],
      [false, true],
    ])('Busy when isLoading=%s and hasError=%s', (isLoading, hasError) => {
      beforeEach(() => {
        return createComponent({
          initialGetters: { isLoading: () => isLoading },
          initialState: { hasError },
        });
      });

      it('displays loading skeletons instead of statistics cards', () => {
        expect(findSkeletonLoaderCards().exists()).toBe(true);
        expect(findSubscriptionSeatsStatisticsCard().exists()).toBe(false);
        expect(findStatisticsSeatsCard().exists()).toBe(false);
      });
    });
  });

  describe('subscription user list', () => {
    it('renders subscription users', async () => {
      await createComponent();

      expect(findSubscriptionUserList().exists()).toBe(true);
    });
  });
});
