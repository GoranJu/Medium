import produce from 'immer';
import getGitlabSubscription from 'ee/fulfillment/shared_queries/gitlab_subscription.query.graphql';

export const PLAN_TYPE = 'Plan';
export const SUBSCRIPTION_TYPE = 'Subscription';

export const writeDataToApolloCache = (
  apolloProvider,
  { subscriptionId = null, planCode = '', planName = '' } = {},
) => {
  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: getGitlabSubscription,
    data: {
      subscription: {
        id: subscriptionId,
        endDate: null,
        startDate: null,
        __typename: SUBSCRIPTION_TYPE,
        plan: {
          __typename: PLAN_TYPE,
          code: planCode,
          name: planName,
        },
      },
    },
  });
  return apolloProvider;
};

export const updateSubscriptionPlanApolloCache = (
  apolloProvider,
  {
    planCode = '',
    planName = '',
    subscriptionId = '',
    subscriptionEndDate = '',
    subscriptionStartDate = '',
  } = {},
) => {
  const sourceData = apolloProvider.clients.defaultClient.cache.readQuery({
    query: getGitlabSubscription,
  });

  if (!sourceData) {
    return;
  }

  const data = produce(sourceData, (draftState) => {
    draftState.subscription = {
      ...draftState.subscription,
      id: subscriptionId,
      endDate: subscriptionEndDate,
      startDate: subscriptionStartDate,
      plan: {
        __typename: PLAN_TYPE,
        code: planCode,
        name: planName,
      },
    };
  });

  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: getGitlabSubscription,
    data,
  });
};
