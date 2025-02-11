import {
  dateAtFirstDayOfMonth,
  nDaysBefore,
  nMonthsBefore,
  toISODateFormat,
} from '~/lib/utils/datetime_utility';
import { BUCKETING_INTERVAL_MONTHLY } from '~/analytics/shared/graphql/constants';
import {
  GENERIC_DASHBOARD_ERROR,
  UNSUPPORTED_PROJECT_NAMESPACE_ERROR,
  SUPPORTED_DORA_METRICS,
} from 'ee/analytics/dashboards/constants';
import { percentChange } from 'ee/analytics/dashboards/utils';
import DoraMetricsByProjectQuery from 'ee/analytics/dashboards/graphql/dora_metrics_by_project.query.graphql';
import { defaultClient } from '../graphql/client';

const calculateTrends = (previous, current) =>
  SUPPORTED_DORA_METRICS.reduce(
    (trends, id) => ({
      ...trends,
      [id]: percentChange({ current: current[id], previous: previous[id] }),
    }),
    {},
  );

const fetchAllProjects = async (params) => {
  const {
    data: {
      group: {
        projects: {
          nodes,
          pageInfo: { endCursor, hasNextPage },
        },
      },
    },
  } = await defaultClient.query({
    query: DoraMetricsByProjectQuery,
    variables: {
      ...params,
      interval: BUCKETING_INTERVAL_MONTHLY,
    },
  });

  if (hasNextPage) {
    const nextNodes = await fetchAllProjects({
      ...params,
      after: endCursor,
    });
    return [...nodes, ...nextNodes];
  }

  return nodes;
};

const formatData = (nodes) => ({
  projects: nodes.map(
    ({
      id,
      name,
      avatarUrl,
      webUrl,
      dora: {
        metrics: [pastMetrics, currentMetrics],
      },
    }) => ({
      id,
      name,
      avatarUrl,
      webUrl,
      trends: calculateTrends(pastMetrics, currentMetrics),
      ...currentMetrics,
    }),
  ),
});

export default async function fetch({ namespace, isProject, setAlerts }) {
  if (isProject) {
    setAlerts({
      title: GENERIC_DASHBOARD_ERROR,
      errors: [UNSUPPORTED_PROJECT_NAMESPACE_ERROR],
      canRetry: false,
    });

    return undefined;
  }

  const thisMonth = dateAtFirstDayOfMonth(new Date());
  const endDate = nDaysBefore(thisMonth, 1);
  const startDate = nMonthsBefore(thisMonth, 2);

  const projects = await fetchAllProjects({
    startDate: toISODateFormat(startDate),
    endDate: toISODateFormat(endDate),
    fullPath: namespace,
  });

  return formatData(projects);
}
