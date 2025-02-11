import { GlAreaChart } from '@gitlab/ui/dist/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SharedRunnerUsageMonthChart from 'ee/usage_quotas/pipelines/components/shared_runner_usage_month_chart.vue';
import { groupUsageDataByYear } from 'ee/usage_quotas/pipelines/utils';
import { mockGetNamespaceCiMinutesUsage } from '../mock_data';

const {
  data: { ciMinutesUsage },
} = mockGetNamespaceCiMinutesUsage;
const usageDataByYear = groupUsageDataByYear(ciMinutesUsage.nodes);

describe('Shared runner usage month chart component', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findAreaChart = () => wrapper.findComponent(GlAreaChart);

  const createComponent = () => {
    wrapper = shallowMountExtended(SharedRunnerUsageMonthChart, {
      propsData: {
        usageDataByYear,
        selectedYear: 2022,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders a area chart component with axis legends', () => {
    expect(findAreaChart().exists()).toBe(true);
    expect(findAreaChart().props('option').xAxis.name).toBe('Month');
    expect(findAreaChart().props('option').yAxis.name).toBe('Duration (min)');
  });

  it('should contain a responsive attribute for the column chart', () => {
    expect(findAreaChart().attributes('responsive')).toBeDefined();
  });
});
