import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import { shallowMount } from '@vue/test-utils';
import { HTTP_STATUS_OK, HTTP_STATUS_NOT_FOUND } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import { createdAfter, createdBefore } from 'jest/analytics/cycle_analytics/mock_data';
import DurationChartLoader from 'ee/analytics/cycle_analytics/components/duration_charts/duration_chart_loader.vue';
import StageChart from 'ee/analytics/cycle_analytics/components/duration_charts/stage_chart.vue';
import OverviewChart from 'ee/analytics/cycle_analytics/components/duration_charts/overview_chart.vue';
import {
  allowedStages as stages,
  transformedDurationData,
  durationOverviewChartPlottableData,
  endpoints,
} from '../../mock_data';

Vue.use(Vuex);

describe('DurationChartLoader', () => {
  let wrapper;
  let mock;

  const [selectedStage] = stages;
  const namespacePath = 'fake/group/path';

  const cycleAnalyticsRequestParams = {
    project_ids: null,
    created_after: '2019-12-11',
    created_before: '2020-01-10',
    author_username: null,
    milestone_title: null,
    assignee_username: null,
  };

  const createWrapper = ({ isOverviewStageSelected = true } = {}) => {
    const store = new Vuex.Store({
      state: {
        selectedStage,
        createdAfter,
        createdBefore,
      },
      getters: {
        isOverviewStageSelected: () => isOverviewStageSelected,
        activeStages: () => stages,
        cycleAnalyticsRequestParams: () => cycleAnalyticsRequestParams,
        namespaceRestApiRequestPath: () => namespacePath,
        currentValueStreamId: () => selectedStage.id,
      },
      mutations: {
        setSelectedStage: (rootState, value) => {
          // eslint-disable-next-line no-param-reassign
          rootState.selectedStage = value;
        },
      },
    });

    wrapper = shallowMount(DurationChartLoader, { store });
    return waitForPromises();
  };

  const findOverviewChart = () => wrapper.findComponent(OverviewChart);
  const findStageChart = () => wrapper.findComponent(StageChart);

  const mockApiData = () => {
    // The first 2 stages have different duration values,
    // all subsequent requests should get the same data
    mock
      .onGet(endpoints.durationData)
      .replyOnce(HTTP_STATUS_OK, transformedDurationData[0].data)
      .onGet(endpoints.durationData)
      .replyOnce(HTTP_STATUS_OK, transformedDurationData[1].data)
      .onGet(endpoints.durationData)
      .reply(HTTP_STATUS_OK, transformedDurationData[2].data);
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('fetches chart data', () => {
    const stagesRequests = stages.map((stage) =>
      expect.objectContaining({
        url: `/${namespacePath}/-/analytics/value_stream_analytics/value_streams/1/stages/${stage.id}/average_duration_chart`,
        params: cycleAnalyticsRequestParams,
      }),
    );

    beforeEach(() => {
      mockApiData();
      return createWrapper();
    });

    it('when the component is created', () => {
      expect(mock.history.get).toEqual(stagesRequests);
    });

    it('when the selectedStage changes', async () => {
      const [, newStage] = stages;
      wrapper.vm.$store.commit('setSelectedStage', newStage);

      await waitForPromises();

      expect(mock.history.get).toEqual([...stagesRequests, ...stagesRequests]);
    });
  });

  describe('overview chart', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('shows the loading state', () => {
        expect(findOverviewChart().props('isLoading')).toBe(true);
      });
    });

    describe('when error is thrown', () => {
      beforeEach(() => {
        mock.onGet(endpoints.durationData).reply(HTTP_STATUS_NOT_FOUND);
        return createWrapper();
      });

      it('shows the error message', () => {
        expect(findOverviewChart().props('errorMessage')).toBe(
          'Request failed with status code 404',
        );
      });
    });

    describe('no data', () => {
      beforeEach(() => {
        mock.onGet(endpoints.durationData).reply(HTTP_STATUS_OK, []);
        return createWrapper();
      });

      it('shows an empty chart', () => {
        expect(findOverviewChart().props('plottableData')).toEqual([]);
      });
    });

    describe('with data', () => {
      beforeEach(() => {
        mockApiData();
        return createWrapper();
      });

      it('shows the chart with the plottable data', () => {
        expect(findOverviewChart().props()).toMatchObject({
          isLoading: false,
          errorMessage: '',
          plottableData: expect.arrayContaining(durationOverviewChartPlottableData),
        });
      });

      it('does not show the stage chart', () => {
        expect(findStageChart().exists()).toBe(false);
      });
    });
  });

  describe('stage chart', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createWrapper({ isOverviewStageSelected: false });
      });

      it('shows the loading state', () => {
        expect(findStageChart().props('isLoading')).toBe(true);
      });
    });

    describe('when error is thrown', () => {
      beforeEach(() => {
        mock.onGet(endpoints.durationData).reply(HTTP_STATUS_NOT_FOUND);
        return createWrapper({ isOverviewStageSelected: false });
      });

      it('shows the error message', () => {
        expect(findStageChart().props('errorMessage')).toBe('Request failed with status code 404');
      });
    });

    describe('no data', () => {
      beforeEach(() => {
        mock.onGet(endpoints.durationData).reply(HTTP_STATUS_OK, []);
        return createWrapper({ isOverviewStageSelected: false });
      });

      it('shows an empty chart', () => {
        expect(findStageChart().props('plottableData')).toEqual([]);
      });
    });

    describe('with data', () => {
      beforeEach(() => {
        mockApiData();
        return createWrapper({ isOverviewStageSelected: false });
      });

      it('shows the chart with the plottable data', () => {
        expect(findStageChart().props()).toMatchObject({
          stageTitle: selectedStage.title,
          isLoading: false,
          errorMessage: '',
          plottableData: expect.arrayContaining([
            ['2019-01-01', 1134000],
            ['2019-01-02', 2321000],
          ]),
        });
      });

      it('does not show the overview chart', () => {
        expect(findOverviewChart().exists()).toBe(false);
      });
    });
  });
});
