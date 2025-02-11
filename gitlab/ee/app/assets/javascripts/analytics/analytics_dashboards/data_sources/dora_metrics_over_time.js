import { BUCKETING_INTERVAL_ALL } from '~/analytics/shared/graphql/constants';
import DoraMetricsQuery from '~/analytics/shared/graphql/dora_metrics.query.graphql';
import { extractQueryResponseFromNamespace, scaledValueForDisplay } from '~/analytics/shared/utils';
import { TABLE_METRICS } from 'ee/analytics/dashboards/constants';
import {
  LAST_180_DAYS,
  DORA_METRIC_QUERY_RANGES,
  startOfTomorrow,
} from 'ee/dora/components/static_data/shared';
import { defaultClient } from '../graphql/client';

const fetchDoraMetricsQuery = async ({ metric, namespace, startDate, endDate }) => {
  const result = await defaultClient.query({
    query: DoraMetricsQuery,
    variables: {
      fullPath: namespace,
      interval: BUCKETING_INTERVAL_ALL,
      startDate,
      endDate,
    },
  });

  const { metrics } = extractQueryResponseFromNamespace({ result, resultKey: 'dora' });
  const { units } = TABLE_METRICS[metric];

  if (!metrics.length) return '-';

  const metricValue = metrics[0][metric] || 0;
  return scaledValueForDisplay(metricValue, units);
};

export default async function fetch({
  namespace,
  query: { metric, date_range: dateRange = LAST_180_DAYS },
  queryOverrides: { date_range: dateRangeOverride = null, ...overridesRest } = {},
}) {
  const dateRangeKey = dateRangeOverride
    ? dateRangeOverride.toUpperCase()
    : dateRange.toUpperCase();

  // Default to 180 days if an invalid date range is given
  const startDate = DORA_METRIC_QUERY_RANGES[dateRangeKey]
    ? DORA_METRIC_QUERY_RANGES[dateRangeKey]
    : DORA_METRIC_QUERY_RANGES[LAST_180_DAYS];

  return fetchDoraMetricsQuery({
    startDate,
    endDate: startOfTomorrow,
    metric,
    namespace,
    ...overridesRest,
  });
}
