import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { sprintf } from '~/locale';
import addOnPurchasesQuery from 'ee/usage_quotas/add_on/graphql/get_add_on_purchases.query.graphql';
import getCurrentLicense from 'ee/admin/subscriptions/show/graphql/queries/get_current_license.query.graphql';
import CodeSuggestionsIntro from 'ee/usage_quotas/code_suggestions/components/code_suggestions_intro.vue';
import CodeSuggestionsInfo from 'ee/usage_quotas/code_suggestions/components/code_suggestions_info_card.vue';
import CodeSuggestionsStatisticsCard from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage_statistics_card.vue';
import SaasAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/saas_add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import { useFakeDate } from 'helpers/fake_date';
import CodeSuggestionsUsageLoader from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage_loader.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  CODE_SUGGESTIONS_TITLE,
  DUO_ENTERPRISE_TITLE,
} from 'ee/usage_quotas/code_suggestions/constants';
import {
  ADD_ON_ERROR_DICTIONARY,
  ADD_ON_PURCHASE_FETCH_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';

import {
  subscriptionActivationFutureDatedNotificationTitle,
  SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT,
} from 'ee/admin/subscriptions/show/constants';

import {
  noAssignedDuoProAddonData,
  noAssignedDuoEnterpriseAddonData,
  noAssignedDuoAddonsData,
  noPurchasedAddonData,
  purchasedAddonFuzzyData,
  currentLicenseData,
} from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('GitLab Duo Usage', () => {
  // Aug 1, 2024
  useFakeDate(2024, 8, 1);

  let wrapper;

  const error = new Error('Something went wrong');

  const noAssignedAddonDataHandler = jest.fn().mockResolvedValue(noAssignedDuoProAddonData);
  const noAssignedEnterpriseAddonDataHandler = jest
    .fn()
    .mockResolvedValue(noAssignedDuoEnterpriseAddonData);
  const noAssignedDuoAddonsDataHandler = jest.fn().mockResolvedValue(noAssignedDuoAddonsData);
  const noPurchasedAddonDataHandler = jest.fn().mockResolvedValue(noPurchasedAddonData);
  const purchasedAddonFuzzyDataHandler = jest.fn().mockResolvedValue(purchasedAddonFuzzyData);
  const currentLicenseDataHandler = jest.fn().mockResolvedValue(currentLicenseData);

  const purchasedAddonErrorHandler = jest.fn().mockRejectedValue(error);
  const currentLicenseErrorHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = ({
    addOnPurchasesHandler = noPurchasedAddonDataHandler,
    currentLicenseHandler = currentLicenseDataHandler,
  }) => {
    return createMockApollo([
      [addOnPurchasesQuery, addOnPurchasesHandler],
      [getCurrentLicense, currentLicenseHandler],
    ]);
  };

  const findCodeSuggestionsIntro = () => wrapper.findComponent(CodeSuggestionsIntro);
  const findCodeSuggestionsInfo = () => wrapper.findComponent(CodeSuggestionsInfo);
  const findCodeSuggestionsStatistics = () => wrapper.findComponent(CodeSuggestionsStatisticsCard);
  const findCodeSuggestionsSubtitle = () => wrapper.findByTestId('code-suggestions-subtitle');
  const findCodeSuggestionsTitle = () => wrapper.findByTestId('code-suggestions-title');
  const findSaasAddOnEligibleUserList = () => wrapper.findComponent(SaasAddOnEligibleUserList);
  const findCodeSuggestionsUsageLoader = () => wrapper.findComponent(CodeSuggestionsUsageLoader);
  const findSelfManagedAddOnEligibleUserList = () =>
    wrapper.findComponent(SelfManagedAddOnEligibleUserList);
  const findErrorAlert = () => wrapper.findByTestId('add-on-purchase-fetch-error');

  const findSubscriptionActivationSuccessAlert = () =>
    wrapper.findByTestId('subscription-activation-success-alert');

  const findSubscriptionFetchErrorAlert = () =>
    wrapper.findByTestId('subscription-fetch-error-alert');

  const findDuoMovedUsageAlert = () => wrapper.findByTestId('duo-moved-usage-alert');

  const createComponent = ({
    addOnPurchasesHandler,
    currentLicenseHandler,
    provideProps,
    waitForApi = true,
  } = {}) => {
    wrapper = shallowMountExtended(CodeSuggestionsUsage, {
      provide: {
        isSaaS: true,
        duoPagePath: '/gitlab_duo',
        ...provideProps,
      },
      apolloProvider: createMockApolloProvider({
        addOnPurchasesHandler,
        currentLicenseHandler,
      }),
    });

    return waitForApi ? waitForPromises() : null;
  };

  describe('loading', () => {
    beforeEach(() => {
      createComponent({ waitForApi: false });
    });

    it('renders code suggestions usage loader', () => {
      expect(findCodeSuggestionsUsageLoader().exists()).toBe(true);
    });

    it('does not render any other usage components', () => {
      expect(findCodeSuggestionsIntro().exists()).toBe(false);
      expect(findCodeSuggestionsInfo().exists()).toBe(false);
      expect(findCodeSuggestionsStatistics().exists()).toBe(false);
      expect(findCodeSuggestionsTitle().exists()).toBe(false);
      expect(findSelfManagedAddOnEligibleUserList().exists()).toBe(false);
      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('when no group id prop is provided', () => {
    beforeEach(() => {
      createComponent({ addOnPurchasesHandler: noAssignedAddonDataHandler });
    });
    it('calls addOnPurchases query with appropriate props', () => {
      expect(noAssignedAddonDataHandler).toHaveBeenCalledWith({
        namespaceId: null,
      });
    });
  });

  describe('when group id prop is provided', () => {
    beforeEach(() => {
      createComponent({
        addOnPurchasesHandler: noAssignedAddonDataHandler,
        provideProps: { groupId: 289561 },
      });
    });
    it('calls addOnPurchases query with appropriate props', () => {
      expect(noAssignedAddonDataHandler).toHaveBeenCalledWith({
        namespaceId: 'gid://gitlab/Group/289561',
      });
    });
  });

  describe('with no code suggestions data', () => {
    describe('when instance is SaaS', () => {
      beforeEach(() => {
        return createComponent();
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('renders code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(true);
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({ provideProps: { isSaaS: false } });
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('renders code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(true);
      });
    });
  });

  describe('with code suggestions data', () => {
    describe('when instance is SaaS', () => {
      describe('when on the `Usage Quotas` page', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedAddonDataHandler,
            provideProps: { groupId: 289561 },
          });
        });

        it('does not render code suggestions title', () => {
          expect(findCodeSuggestionsTitle().exists()).toBe(false);
        });

        it('does not render code suggestions subtitle', () => {
          expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
        });

        it('does not render code suggestions intro', () => {
          expect(findCodeSuggestionsIntro().exists()).toBe(false);
        });

        it('displays the moved usage alert', () => {
          expect(findDuoMovedUsageAlert().exists()).toBe(true);
          expect(findDuoMovedUsageAlert().text()).toContain(
            'GitLab Duo seat assignment is now located in GitLab Duo settings.',
          );
        });
      });

      describe('when on the standalone page', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedAddonDataHandler,
            provideProps: { isStandalonePage: true, groupId: 289561 },
          });
        });

        it('renders code suggestions title and pro tier badge', () => {
          expect(findCodeSuggestionsTitle().text()).toBe('Seat utilization');
        });

        it('renders code suggestions subtitle', () => {
          expect(findCodeSuggestionsSubtitle().text()).toBe(
            sprintf('Manage seat assignments for %{addOnName} within your group.', {
              addOnName: CODE_SUGGESTIONS_TITLE,
            }),
          );
        });

        it('does not display the moved usage alert', () => {
          expect(findDuoMovedUsageAlert().exists()).toBe(false);
        });
      });

      describe('with Duo Pro add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedAddonDataHandler,
            provideProps: { isStandalonePage: true, groupId: 289561 },
          });
        });

        it('renders code suggestions statistics card for duo pro', () => {
          expect(findCodeSuggestionsStatistics().props()).toEqual({
            usageValue: 0,
            totalValue: 20,
            duoTier: 'pro',
          });
        });

        it('renders code suggestions info card for duo pro', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
          expect(findCodeSuggestionsInfo().props()).toEqual({
            groupId: 289561,
            duoTier: 'pro',
          });
        });
      });

      describe('with Duo Enterprise add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedEnterpriseAddonDataHandler,
            provideProps: { isStandalonePage: true, groupId: 289561 },
          });
        });

        it('renders code suggestions statistics card for duo enterprise', () => {
          expect(findCodeSuggestionsStatistics().props()).toEqual({
            usageValue: 0,
            totalValue: 20,
            duoTier: 'enterprise',
          });
        });

        it('renders code suggestions info card for duo enterprise', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
          expect(findCodeSuggestionsInfo().props()).toEqual({
            groupId: 289561,
            duoTier: 'enterprise',
          });
        });
      });

      describe('with both Duo Pro and Enterprise add-ons enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedDuoAddonsDataHandler,
            provideProps: { isStandalonePage: true, groupId: 289561 },
          });
        });

        it('renders addon user list for duo enterprise', () => {
          expect(findSaasAddOnEligibleUserList().props()).toEqual({
            addOnPurchaseId: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/4',
            duoTier: 'enterprise',
          });
        });

        it('renders code suggestions statistics card for duo enterprise', () => {
          expect(findCodeSuggestionsStatistics().props()).toEqual({
            usageValue: 0,
            totalValue: 20,
            duoTier: 'enterprise',
          });
        });

        it('renders code suggestions info card for duo enterprise', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
          expect(findCodeSuggestionsInfo().props()).toEqual({
            groupId: 289561,
            duoTier: 'enterprise',
          });
        });
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({
          addOnPurchasesHandler: noAssignedAddonDataHandler,
          provideProps: { isSaaS: false },
        });
      });

      it('renders code suggestions title and pro tier badge', () => {
        expect(findCodeSuggestionsTitle().text()).toBe('Seat utilization');
      });

      it('renders code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().text()).toBe(
          sprintf('Manage seat assignments for %{addOnName}.', {
            addOnName: CODE_SUGGESTIONS_TITLE,
          }),
        );
      });

      describe('with Duo Enterprise add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchasesHandler: noAssignedEnterpriseAddonDataHandler,
            provideProps: { isSaaS: false },
          });
        });

        it('renders code suggestions title and enterprise tier badge', () => {
          expect(findCodeSuggestionsTitle().text()).toBe('Seat utilization');
        });

        it('renders code suggestions subtitle', () => {
          expect(findCodeSuggestionsSubtitle().text()).toBe(
            sprintf('Manage seat assignments for %{addOnName}.', {
              addOnName: DUO_ENTERPRISE_TITLE,
            }),
          );
        });
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('renders code suggestions statistics card', () => {
        expect(findCodeSuggestionsStatistics().props()).toEqual({
          usageValue: 0,
          totalValue: 20,
          duoTier: 'pro',
        });
      });

      it('renders code suggestions info card', () => {
        expect(findCodeSuggestionsInfo().exists()).toBe(true);
      });
    });
  });

  describe('add on eligible user list', () => {
    it('renders addon user list for SaaS instance for SaaS', async () => {
      createComponent({
        addOnPurchasesHandler: noAssignedAddonDataHandler,
        provideProps: { isSaaS: true, isStandalonePage: true },
      });
      await waitForPromises();

      expect(findSaasAddOnEligibleUserList().props()).toEqual({
        addOnPurchaseId: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        duoTier: 'pro',
      });
    });

    it('renders addon user list for SM instance for SM', async () => {
      createComponent({
        addOnPurchasesHandler: noAssignedAddonDataHandler,
        provideProps: { isSaaS: false },
      });
      await waitForPromises();

      expect(findSelfManagedAddOnEligibleUserList().props()).toEqual({
        addOnPurchaseId: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        duoTier: 'pro',
      });
    });
  });

  describe('with fuzzy code suggestions data', () => {
    beforeEach(() => {
      return createComponent({ addOnPurchasesHandler: purchasedAddonFuzzyDataHandler });
    });

    it('renders code suggestions intro', () => {
      expect(findCodeSuggestionsIntro().exists()).toBe(true);
    });
  });

  describe('with errors', () => {
    describe('when instance is SaaS', () => {
      beforeEach(() => {
        return createComponent({ addOnPurchasesHandler: purchasedAddonErrorHandler });
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('captures the original error', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(error, {
          tags: { vue_component: 'CodeSuggestionsUsage' },
        });
      });

      it('shows an error alert with cause', () => {
        expect(findErrorAlert().props('errorDictionary')).toMatchObject(ADD_ON_ERROR_DICTIONARY);
        const caughtError = findErrorAlert().props('error');
        expect(caughtError.cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({
          addOnPurchasesHandler: purchasedAddonErrorHandler,
          provideProps: { isSaaS: false },
        });
      });

      it('renders code suggestions title and pro tier badge', () => {
        expect(findCodeSuggestionsTitle().text()).toBe('Seat utilization');
      });

      it('renders code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().text()).toBe(
          sprintf('Manage seat assignments for %{addOnName}.', {
            addOnName: CODE_SUGGESTIONS_TITLE,
          }),
        );
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('captures the original error', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(error, {
          tags: { vue_component: 'CodeSuggestionsUsage' },
        });
      });

      it('shows an error alert with cause', () => {
        expect(findErrorAlert().props('errorDictionary')).toMatchObject(ADD_ON_ERROR_DICTIONARY);
        const caughtError = findErrorAlert().props('error');
        expect(caughtError.cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
      });
    });
  });

  describe('Subscription Activation Form', () => {
    describe('activating the license', () => {
      beforeEach(async () => {
        createComponent({
          currentLicenseHandler: currentLicenseDataHandler,
          provideProps: { isSaaS: false },
        });

        await waitForPromises();
      });

      it('passes the correct data to the code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().props()).toMatchObject({
          subscription: currentLicenseData.data.currentLicense,
        });
      });

      it('shows the activation success notification', async () => {
        findCodeSuggestionsIntro().vm.$emit(SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT, {
          startsAt: '2024-08-01',
        });

        await waitForPromises();

        expect(findSubscriptionActivationSuccessAlert().props('title')).toBe(
          'Your subscription was successfully activated.',
        );
      });

      it('shows the future dated activation success notification', async () => {
        findCodeSuggestionsIntro().vm.$emit(SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT, {
          startsAt: '2025-08-01',
        });

        await waitForPromises();

        expect(findSubscriptionActivationSuccessAlert().props('title')).toBe(
          subscriptionActivationFutureDatedNotificationTitle,
        );
      });

      it('calls refetch to update component', async () => {
        findCodeSuggestionsIntro().vm.$emit(SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT, {
          startsAt: '2025-08-01',
        });

        await waitForPromises();

        expect(noPurchasedAddonDataHandler).toHaveBeenCalledTimes(2);
        expect(currentLicenseDataHandler).toHaveBeenCalledTimes(2);
      });
    });

    describe('when fetch subscription with error', () => {
      describe('when instance is SaaS', () => {
        beforeEach(async () => {
          createComponent({
            currentLicenseHandler: currentLicenseErrorHandler,
          });

          await waitForPromises();
        });

        it('does not show an error alert', () => {
          expect(currentLicenseErrorHandler).not.toHaveBeenCalled();
          expect(findSubscriptionFetchErrorAlert().exists()).toBe(false);
        });
      });

      describe('when instance is SM', () => {
        beforeEach(async () => {
          createComponent({
            currentLicenseHandler: currentLicenseErrorHandler,
            provideProps: { isSaaS: false },
          });

          await waitForPromises();
        });

        it('shows an error alert with cause', () => {
          expect(currentLicenseErrorHandler).toHaveBeenCalledTimes(1);
          expect(findSubscriptionFetchErrorAlert().props('title')).toBe('Subscription unavailable');
        });
      });
    });
  });
});
