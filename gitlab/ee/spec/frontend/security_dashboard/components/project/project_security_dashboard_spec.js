import { GlLoadingIcon, GlSprintf, GlLink } from '@gitlab/ui';
import { GlLineChart } from '@gitlab/ui/dist/charts';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import SecurityTrainingPromoBanner from 'ee/security_dashboard/components/project/security_training_promo_banner.vue';
import ProjectSecurityDashboard from 'ee/security_dashboard/components/project/project_security_dashboard.vue';
import projectsHistoryQuery from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_by_day_and_count.query.graphql';
import severitiesCountQuery from 'ee/security_dashboard/graphql/queries/vulnerability_severities_count.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useFakeDate } from 'helpers/fake_date';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mockProjectSecurityChartsWithData, mockSeverityCountsWithData } from '../../mock_data';

Vue.use(VueApollo);

describe('Project Security Dashboard component', () => {
  let wrapper;
  let severitiesCountQueryHandler;

  const projectFullPath = 'project/path';

  const findLineChart = () => wrapper.findComponent(GlLineChart);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findSecurityTrainingPromoBanner = () => wrapper.findComponent(SecurityTrainingPromoBanner);

  const createApolloProvider = (...queries) => {
    return createMockApollo([...queries]);
  };

  const createWrapper = ({
    historyQueryData,
    severitiesCountQueryData,
    shouldShowPromoBanner = false,
  } = {}) => {
    severitiesCountQueryHandler = jest.fn().mockResolvedValue(severitiesCountQueryData);

    wrapper = shallowMountExtended(ProjectSecurityDashboard, {
      apolloProvider: createApolloProvider(
        [projectsHistoryQuery, jest.fn().mockResolvedValue(historyQueryData)],
        [severitiesCountQuery, severitiesCountQueryHandler],
      ),
      propsData: {
        projectFullPath,
        shouldShowPromoBanner,
      },
      stubs: {
        GlSprintf,
        PageHeading,
      },
    });
  };

  it('should display page header and subheader', () => {
    createWrapper();

    expect(wrapper.findByTestId('page-heading').text()).toBe('Security dashboard');
    expect(wrapper.findByTestId('page-heading-description').text()).toBe(
      'Historical view of open vulnerabilities in the default branch. Excludes vulnerabilities that were resolved or dismissed. Learn more.',
    );
    expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
      '/help/user/application_security/security_dashboard/_index#project-security-dashboard',
    );
  });

  it('should fetch the latest vulnerability count for "detected" and "confirmed" states', () => {
    createWrapper();

    expect(severitiesCountQueryHandler).toHaveBeenCalledWith(
      expect.objectContaining({ state: ['DETECTED', 'CONFIRMED'] }),
    );
  });

  describe('when query is loading', () => {
    it('should only show the loading icon', () => {
      createWrapper();

      expect(findLineChart().exists()).toBe(false);
      expect(findSecurityTrainingPromoBanner().exists()).toBe(false);
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('when there is history data', () => {
    useFakeDate(2021, 3, 11);
    const todayIso = '2021-04-11';

    beforeEach(async () => {
      createWrapper({
        historyQueryData: mockProjectSecurityChartsWithData(),
        severitiesCountQueryData: mockSeverityCountsWithData(),
      });
      await waitForPromises();
    });

    it('should display the chart with data', () => {
      expect(findLineChart().props('data')).toMatchSnapshot();
    });

    it.each(['critical', 'high', 'medium', 'info', 'unknown'])(
      'should use the up-to-date vulnerability count for the latest date for "%s" severity findings',
      (severity) => {
        const series = findLineChart()
          .props('data')
          .find(({ key }) => key === severity);
        const trendingData =
          mockProjectSecurityChartsWithData().data.project.vulnerabilitiesCountByDay.nodes;

        const todaysTrendingSeverityCount = trendingData.find(({ date }) => date === todayIso)[
          severity
        ];
        const latestSeverityCount =
          mockSeverityCountsWithData().data.project.vulnerabilitySeveritiesCount[severity];

        const [lastSeriesDate, lastSeriesCount] = series.data.at(-1);

        expect(lastSeriesDate).toBe(todayIso);
        expect(lastSeriesCount).toBe(latestSeverityCount);
        expect(lastSeriesCount).not.toBe(todaysTrendingSeverityCount);
      },
    );

    it('should display the chart with responsive attribute', () => {
      expect(findLineChart().attributes('responsive')).toBeDefined();
    });

    it('should not display the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('sets the contains `toolbox.show` option', () => {
      const { toolbox } = findLineChart().props('option');
      expect(toolbox).toMatchObject({ show: true });
    });

    it('contains the timeline slider', () => {
      const { dataZoom } = findLineChart().props('option');
      expect(dataZoom[0]).toMatchObject({
        type: 'slider',
        startValue: '2021-03-12',
      });
    });
  });

  describe('promo banner', () => {
    it.each([[true], [false]])('when prop is %s', async (shouldShowPromoBanner) => {
      createWrapper({ shouldShowPromoBanner });
      await waitForPromises();
      expect(findSecurityTrainingPromoBanner().exists()).toBe(shouldShowPromoBanner);
    });
  });
});
