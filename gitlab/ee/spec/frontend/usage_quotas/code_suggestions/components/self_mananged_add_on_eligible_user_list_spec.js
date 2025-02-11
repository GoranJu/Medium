import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { DEFAULT_PER_PAGE } from '~/api';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/self_managed_add_on_eligible_users.query.graphql';
import AddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';
import {
  ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
  ADD_ON_ERROR_DICTIONARY,
} from 'ee/usage_quotas/error_constants';
import {
  DUO_PRO,
  DUO_ENTERPRISE,
  ADD_ON_CODE_SUGGESTIONS,
  ADD_ON_DUO_ENTERPRISE,
  SORT_OPTIONS,
  DEFAULT_SORT_OPTION,
} from 'ee/usage_quotas/code_suggestions/constants';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import {
  OPERATORS_IS,
  TOKEN_TITLE_ASSIGNED_SEAT,
  TOKEN_TYPE_ASSIGNED_SEAT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  eligibleSMUsers,
  pageInfoWithMorePages,
} from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('Add On Eligible User List', () => {
  let wrapper;
  let enableAddOnUsersFiltering = false;
  let enableAddOnUsersPagesizeSelection = false;

  const addOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/1';
  const duoEnterpriseAddOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/2';

  const error = new Error('Error');
  const addOnEligibleUsersResponse = {
    data: {
      selfManagedAddOnEligibleUsers: {
        nodes: eligibleSMUsers,
        pageInfo: pageInfoWithMorePages,
        __typename: 'AddOnUserConnection',
      },
    },
  };

  const defaultPaginationParams = {
    first: DEFAULT_PER_PAGE,
    last: null,
    after: null,
    before: null,
    sort: DEFAULT_SORT_OPTION,
  };

  const duoTier = DUO_PRO;
  const defaultQueryVariables = {
    addOnType: ADD_ON_CODE_SUGGESTIONS,
    addOnPurchaseIds: [addOnPurchaseId],
    ...defaultPaginationParams,
  };
  const defaultDuoEnterpriseQueryVariables = {
    addOnType: ADD_ON_DUO_ENTERPRISE,
    addOnPurchaseIds: [duoEnterpriseAddOnPurchaseId],
    ...defaultPaginationParams,
  };

  const addOnEligibleUsersDataHandler = jest.fn().mockResolvedValue(addOnEligibleUsersResponse);
  const addOnEligibleUsersErrorHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = (handler) =>
    createMockApollo([[getAddOnEligibleUsers, handler]]);

  const createComponent = ({ props = {}, handler = addOnEligibleUsersDataHandler } = {}) => {
    wrapper = shallowMountExtended(SelfManagedAddOnEligibleUserList, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        addOnPurchaseId,
        duoTier,
        ...props,
      },
      provide: {
        glFeatures: {
          enableAddOnUsersFiltering,
          enableAddOnUsersPagesizeSelection,
        },
      },
    });

    return waitForPromises();
  };

  const findAddOnEligibleUserList = () => wrapper.findComponent(AddOnEligibleUserList);
  const findAddOnEligibleUsersFetchError = () =>
    wrapper.findByTestId('add-on-eligible-users-fetch-error');
  const findSearchAndSortBar = () => wrapper.findComponent(SearchAndSortBar);

  describe('add-on eligible user list', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('displays add-on eligible user list', () => {
      const expectedProps = {
        addOnPurchaseId,
        duoTier: DUO_PRO,
        isLoading: false,
        pageInfo: pageInfoWithMorePages,
        pageSize: DEFAULT_PER_PAGE,
        search: '',
        users: eligibleSMUsers,
      };

      expect(findAddOnEligibleUserList().props()).toEqual(expectedProps);
    });

    it('calls addOnEligibleUsers query with appropriate params', () => {
      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith(defaultQueryVariables);
    });

    describe('when enableAddOnUsersFiltering is enabled', () => {
      beforeEach(() => {
        enableAddOnUsersFiltering = true;
        return createComponent();
      });

      it('passes the correct sort options to <search-and-sort-bar>', () => {
        expect(findSearchAndSortBar().props('sortOptions')).toStrictEqual(SORT_OPTIONS);
      });

      it('passes the correct tokens to <search-and-sort-bar>', () => {
        expect(findSearchAndSortBar().props('tokens')).toStrictEqual([
          {
            options: [
              { value: 'true', title: 'Yes' },
              { value: 'false', title: 'No' },
            ],
            icon: 'user',
            operators: OPERATORS_IS,
            title: TOKEN_TITLE_ASSIGNED_SEAT,
            token: BaseToken,
            type: TOKEN_TYPE_ASSIGNED_SEAT,
            unique: true,
          },
        ]);
      });

      it('fetches users list by assigned seats', async () => {
        const filterOptions = { filterByAssignedSeat: 'true' };

        findSearchAndSortBar().vm.$emit('onFilter', { filterByAssignedSeat: 'true' });
        await waitForPromises();

        expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
          ...defaultQueryVariables,
          ...filterOptions,
        });
      });
    });

    describe('with Duo Enterprise add-on tier', () => {
      beforeEach(() => {
        return createComponent({
          props: { duoTier: DUO_ENTERPRISE, addOnPurchaseId: duoEnterpriseAddOnPurchaseId },
        });
      });

      it('calls addOnEligibleUsers query with appropriate params', () => {
        expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith(
          defaultDuoEnterpriseQueryVariables,
        );
      });
    });

    describe('when there is an error fetching add on eligible users', () => {
      beforeEach(() => {
        return createComponent({ handler: addOnEligibleUsersErrorHandler });
      });

      it('displays add-on eligible user list', () => {
        const expectedProps = {
          addOnPurchaseId,
          duoTier: DUO_PRO,
          isLoading: false,
          pageInfo: undefined,
          pageSize: DEFAULT_PER_PAGE,
          search: '',
          users: [],
        };

        expect(findAddOnEligibleUserList().props()).toEqual(expectedProps);
      });

      it('sends the error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException.mock.calls[0][0]).toEqual(error);
      });

      it('shows an error alert', () => {
        const expectedProps = {
          dismissible: true,
          error: ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
          errorDictionary: ADD_ON_ERROR_DICTIONARY,
        };

        expect(findAddOnEligibleUsersFetchError().props()).toEqual(
          expect.objectContaining(expectedProps),
        );
      });

      it('clears error alert when dismissed', async () => {
        findAddOnEligibleUsersFetchError().vm.$emit('dismiss');

        await nextTick();

        expect(findAddOnEligibleUsersFetchError().exists()).toBe(false);
      });
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays add-on eligible user list in loading state', () => {
      expect(findAddOnEligibleUserList().props('isLoading')).toBe(true);
    });
  });

  describe('pagination', () => {
    const { startCursor, endCursor } = pageInfoWithMorePages;

    beforeEach(() => {
      return createComponent();
    });

    it('fetches next page of users on next', async () => {
      findAddOnEligibleUserList().vm.$emit('next', endCursor);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        after: endCursor,
      });
    });

    it('fetches prev page of users on prev', async () => {
      findAddOnEligibleUserList().vm.$emit('prev', startCursor);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        first: null,
        last: 20,
        before: startCursor,
      });
    });
  });

  describe('with page size selection', () => {
    beforeEach(() => {
      enableAddOnUsersPagesizeSelection = true;
      return createComponent();
    });

    it('fetches changed number of user items', async () => {
      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        first: DEFAULT_PER_PAGE,
      });

      const pageSize = 50;
      findAddOnEligibleUserList().vm.$emit('page-size-change', pageSize);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        first: pageSize,
      });
    });
  });

  describe('search', () => {
    const filterOptions = { search: 'test' };

    beforeEach(() => {
      return createComponent();
    });

    it('fetches users list matching the search term', async () => {
      findSearchAndSortBar().vm.$emit('onFilter', filterOptions);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        ...filterOptions,
      });
    });
  });

  describe('sort', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('fetches users list with the default sorting value', async () => {
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        sort: DEFAULT_SORT_OPTION,
      });
    });
  });
});
