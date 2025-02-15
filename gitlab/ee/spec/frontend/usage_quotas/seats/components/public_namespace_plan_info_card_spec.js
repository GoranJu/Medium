import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf } from '@gitlab/ui';
import Tracking from '~/tracking';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SubscriptionUsageStatisticsCard from 'ee/usage_quotas/seats/components/public_namespace_plan_info_card.vue';
import { EXPLORE_PAID_PLANS_CLICKED, PLAN_CODE_FREE } from 'ee/usage_quotas/seats/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { createMockClient } from 'helpers/mock_apollo_helper';
import getGitlabSubscriptionQuery from 'ee/fulfillment/shared_queries/gitlab_subscription.query.graphql';
import { getMockSubscriptionData } from 'ee_jest/usage_quotas/seats/mock_data';

Vue.use(VueApollo);

describe('PublicNamespacePlanInfoCard', () => {
  let wrapper;

  const explorePlansPath = 'https://gitlab.com/explore-plans-path';
  const namespaceId = 16;

  const findExplorePaidPlansButton = () => wrapper.findByTestId('explore-plans');
  const findDescriptionTitle = () => wrapper.findByTestId('title');
  const findFreePlanInfo = () => wrapper.findByTestId('free-plan-info');

  const createMockApolloProvider = ({ subscriptionData }) => {
    const mockGitlabClient = createMockClient();
    const mockApollo = new VueApollo({
      defaultClient: mockGitlabClient,
    });

    mockApollo.clients.defaultClient.cache.writeQuery({
      query: getGitlabSubscriptionQuery,
      data: subscriptionData,
    });
    return mockApollo;
  };

  const createWrapper = ({ subscriptionData = {}, provide = {} } = {}) => {
    const apolloProvider = createMockApolloProvider({ subscriptionData });
    wrapper = shallowMountExtended(SubscriptionUsageStatisticsCard, {
      apolloProvider,
      provide: {
        explorePlansPath,
        namespaceId,
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });

    return waitForPromises();
  };

  describe('when loading', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('does not render the `Explore plans` button', () => {
      expect(findExplorePaidPlansButton().exists()).toBe(false);
    });
  });

  describe('when finished loading', () => {
    beforeEach(() => {
      return createWrapper();
    });

    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('renders the `Explore plans` button', () => {
      expect(findExplorePaidPlansButton().exists()).toBe(true);
    });
  });

  describe('when has a free plan', () => {
    beforeEach(() => {
      const subscriptionData = getMockSubscriptionData({ code: PLAN_CODE_FREE, name: 'Free' });
      return createWrapper({ subscriptionData });
    });

    it('passes the correct href to `Explore paid plans` button', () => {
      expect(findExplorePaidPlansButton().attributes('href')).toBe(explorePlansPath);
    });

    it('renders the title', () => {
      expect(findDescriptionTitle().text()).toBe('Free Plan');
    });

    it('renders the free plan info', () => {
      expect(findFreePlanInfo().text()).toBe(
        'You can upgrade to a paid tier to get access to more features.',
      );
    });
  });

  describe('when clicking on `Explore paid plans`', () => {
    beforeEach(() => {
      const subscriptionData = getMockSubscriptionData({ code: PLAN_CODE_FREE, name: 'Free' });
      jest.spyOn(Tracking, 'event');
      return createWrapper({ subscriptionData });
    });

    it('tracks the event', () => {
      findExplorePaidPlansButton().vm.$emit('click');

      expect(Tracking.event).toHaveBeenCalledWith(undefined, 'click_button', {
        label: EXPLORE_PAID_PLANS_CLICKED,
      });
    });
  });
});
