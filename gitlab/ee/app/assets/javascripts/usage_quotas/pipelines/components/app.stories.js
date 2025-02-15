import {
  mockGetNamespaceCiMinutesUsage,
  mockGetProjectsCiMinutesUsage,
} from 'ee_jest/usage_quotas/pipelines/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import getNamespaceCiMinutesUsage from '../graphql/queries/namespace_ci_minutes_usage.query.graphql';
import getProjectsCiMinutesUsage from '../graphql/queries/projects_ci_minutes_usage.query.graphql';
import PipelineUsageApp from './app.vue';

const meta = {
  title: 'ee/usage_quotas/pipelines/app',
  component: PipelineUsageApp,
};

export default meta;

const ciMinutesLastResetDate =
  mockGetProjectsCiMinutesUsage.data.ciMinutesUsage.nodes[0].monthIso8601;

const createTemplate = (config = {}) => {
  let { provide, apolloProvider } = config;

  if (provide == null) {
    provide = {};
  }

  if (apolloProvider == null) {
    const requestHandlers = [
      [getNamespaceCiMinutesUsage, () => Promise.resolve(mockGetNamespaceCiMinutesUsage)],
      [
        getProjectsCiMinutesUsage,
        ({ date }) => {
          // Return data only when a particular month is selected, for which we
          // have mocks.
          if (date === ciMinutesLastResetDate) {
            return Promise.resolve(mockGetProjectsCiMinutesUsage);
          }

          // Return an empty response otherwise
          return {
            data: {
              ciMinutesUsage: {
                nodes: [],
              },
            },
          };
        },
      ],
    ];
    apolloProvider = createMockApollo(requestHandlers);
  }

  return (args, { argTypes }) => ({
    components: { PipelineUsageApp },
    apolloProvider,
    provide: {
      pageSize: 20,
      namespaceId: 35,
      namespaceActualPlanName: 'free',
      userNamespace: false,
      ciMinutesAnyProjectEnabled: true,
      ciMinutesDisplayMinutesAvailableData: true,
      ciMinutesLastResetDate,
      ciMinutesMonthlyMinutesLimit: 10000,
      ciMinutesMonthlyMinutesUsed: 2000,
      ciMinutesMonthlyMinutesUsedPercentage: 20,
      ciMinutesPurchasedMinutesLimit: 0,
      ciMinutesPurchasedMinutesUsed: 0,
      ciMinutesPurchasedMinutesUsedPercentage: 0,
      buyAdditionalMinutesPath: '/-/subscriptions/buy_minutes?selected_group=35',
      buyAdditionalMinutesTarget: '_self',
      ...provide,
    },
    props: Object.keys(argTypes),
    template: '<pipeline-usage-app />',
  });
};

export const Default = {
  render: createTemplate(),
};

export const Unused = {
  render: createTemplate({
    provide: {
      ciMinutesMonthlyMinutesLimit: 10000,
      ciMinutesMonthlyMinutesUsed: 0,
      ciMinutesMonthlyMinutesUsedPercentage: 0,
    },
  }),
};

export const Unlimited = {
  render: createTemplate({
    provide: {
      ciMinutesAnyProjectEnabled: true,
      ciMinutesDisplayMinutesAvailableData: false,
      ciMinutesMonthlyMinutesLimit: 'Unlimited',
      ciMinutesMonthlyMinutesUsedPercentage: 0,
    },
  }),
};

export const InstanceRunnersDisabled = {
  render: createTemplate({
    provide: {
      ciMinutesMonthlyMinutesLimit: 'Not supported',
      ciMinutesAnyProjectEnabled: false,
      ciMinutesDisplayMinutesAvailableData: false,
    },
  }),
};

export const WithPurchasedMinutes = {
  render: createTemplate({
    provide: {
      ciMinutesMonthlyMinutesLimit: 10000,
      ciMinutesMonthlyMinutesUsed: 10000,
      ciMinutesMonthlyMinutesUsedPercentage: 100,
      ciMinutesPurchasedMinutesLimit: 1000,
      ciMinutesPurchasedMinutesUsed: 200,
      ciMinutesPurchasedMinutesUsedPercentage: 20,
    },
  }),
};

export const WithPurchasedMinutesUnused = {
  render: createTemplate({
    provide: {
      ciMinutesMonthlyMinutesLimit: 10000,
      ciMinutesMonthlyMinutesUsed: 9000,
      ciMinutesMonthlyMinutesUsedPercentage: 90,
      ciMinutesPurchasedMinutesLimit: 1000,
      ciMinutesPurchasedMinutesUsed: 0,
      ciMinutesPurchasedMinutesUsedPercentage: 0,
    },
  }),
};

export const Loading = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getNamespaceCiMinutesUsage, () => new Promise(() => {})],
      [getProjectsCiMinutesUsage, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};

export const LoadingError = {
  render: (...args) => {
    const handlerWithAnError = () => Promise.reject(new Error('500 Internal Server Error'));
    const apolloProvider = createMockApollo([
      [getNamespaceCiMinutesUsage, handlerWithAnError],
      [getProjectsCiMinutesUsage, handlerWithAnError],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};
