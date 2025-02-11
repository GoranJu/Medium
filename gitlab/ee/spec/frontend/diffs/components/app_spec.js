import { shallowMount } from '@vue/test-utils';

import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getMRCodequalityAndSecurityReports from 'ee_else_ce/diffs/components/graphql/get_mr_codequality_and_security_reports.query.graphql';
import { TEST_HOST } from 'spec/test_constants';
import App, { FINDINGS_POLL_INTERVAL } from '~/diffs/components/app.vue';
import DiffFile from '~/diffs/components/diff_file.vue';
import store from '~/mr_notes/stores';
import { pinia } from '~/pinia/instance';

import {
  codeQualityNewErrorsHandler,
  SASTParsedHandler,
  SASTParsingAndParsedHandler,
  SASTErrorHandler,
  codeQualityErrorAndParsed,
  requestError,
  SAST_REPORT_DATA,
} from './mocks/queries';

const TEST_ENDPOINT = `${TEST_HOST}/diff/endpoint`;

jest.mock('~/mr_notes/stores', () => jest.requireActual('helpers/mocks/mr_notes/stores'));
Vue.use(VueApollo);

describe('diffs/components/app', () => {
  let fakeApollo;
  let wrapper;

  const createComponent = ({
    props = {},
    baseConfig = {},
    queryHandler = codeQualityNewErrorsHandler,
    extendStore = () => {},
  } = {}) => {
    store.reset();
    store.getters.isNotesFetched = false;
    store.getters.getNoteableData = {
      current_user: {
        can_create_note: true,
      },
    };
    store.getters['findingsDrawer/activeDrawer'] = {};
    store.getters['diffs/diffFiles'] = [];
    store.getters['diffs/flatBlobsList'] = [];
    store.getters['diffs/isBatchLoading'] = false;
    store.getters['diffs/isBatchLoadingError'] = false;
    store.getters['diffs/whichCollapsedTypes'] = { any: false };

    store.state.diffs.isLoading = false;
    store.state.findingsDrawer = { activeDrawer: false };

    store.state.diffs.isTreeLoaded = true;

    store.dispatch('diffs/setBaseConfig', {
      endpoint: TEST_ENDPOINT,
      endpointMetadata: `${TEST_HOST}/diff/endpointMetadata`,
      endpointBatch: `${TEST_HOST}/diff/endpointBatch`,
      endpointDiffForPath: TEST_ENDPOINT,
      projectPath: 'namespace/project',
      dismissEndpoint: '',
      showSuggestPopover: true,
      mrReviews: {},
      ...baseConfig,
    });

    extendStore(store);

    fakeApollo = createMockApollo([[getMRCodequalityAndSecurityReports, queryHandler]]);

    wrapper = shallowMount(App, {
      apolloProvider: fakeApollo,
      propsData: {
        endpointCoverage: `${TEST_HOST}/diff/endpointCoverage`,
        endpointCodequality: '',
        sastReportAvailable: false,
        currentUser: {},
        changesEmptyStateIllustration: '',
        ...props,
      },
      mocks: {
        $store: store,
        // DiffFile,
      },
      pinia,
    });
  };

  describe('EE codequality diff', () => {
    it('polls Code Quality data via GraphQL and not via REST when codequalityReportAvailable is true', async () => {
      createComponent({
        props: { shouldShow: true, codequalityReportAvailable: true },
        queryHandler: codeQualityErrorAndParsed,
      });
      await waitForPromises();
      expect(codeQualityErrorAndParsed).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(codeQualityErrorAndParsed).toHaveBeenCalledTimes(2);
    });

    it('does not poll Code Quality data via GraphQL when codequalityReportAvailable is false', async () => {
      createComponent({ props: { shouldShow: true, codequalityReportAvailable: false } });
      await waitForPromises();
      expect(codeQualityNewErrorsHandler).toHaveBeenCalledTimes(0);
    });

    it('stops polling when newErrors in response are defined', async () => {
      createComponent({ props: { shouldShow: true, codequalityReportAvailable: true } });

      await waitForPromises();

      expect(codeQualityNewErrorsHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(codeQualityNewErrorsHandler).toHaveBeenCalledTimes(1);
    });

    it('does not fetch code quality data when endpoint is blank', () => {
      createComponent({ props: { shouldShow: false, endpointCodequality: '' } });
      expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
    });
  });

  describe('EE SAST diff', () => {
    it('polls SAST data when sastReportAvailable is true', async () => {
      createComponent({
        props: { shouldShow: true, sastReportAvailable: true },
        queryHandler: SASTParsingAndParsedHandler,
      });
      await waitForPromises();

      expect(SASTParsingAndParsedHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(SASTParsingAndParsedHandler).toHaveBeenCalledTimes(2);
    });

    it('stops polling when sastReport status is PARSED', async () => {
      createComponent({
        props: { shouldShow: true, sastReportAvailable: true },
        queryHandler: SASTParsedHandler,
      });

      await waitForPromises();

      expect(SASTParsedHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(SASTParsedHandler).toHaveBeenCalledTimes(1);
    });

    it('stops polling on request error', async () => {
      createComponent({
        props: { shouldShow: true, sastReportAvailable: true },
        queryHandler: requestError,
      });
      await waitForPromises();

      expect(requestError).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(requestError).toHaveBeenCalledTimes(1);
    });

    it('stops polling on response status error', async () => {
      createComponent({
        props: { shouldShow: true, sastReportAvailable: true },
        queryHandler: SASTErrorHandler,
      });
      await waitForPromises();

      expect(SASTErrorHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(SASTErrorHandler).toHaveBeenCalledTimes(1);
    });

    it('does not fetch SAST data when sastReportAvailable is false', () => {
      createComponent({ props: { shouldShow: false } });
      expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
    });

    it('passes the SAST report-data to the diff component', async () => {
      createComponent({
        props: {
          shouldShow: true,
          sastReportAvailable: true,
        },
        baseConfig: {
          viewDiffsFileByFile: true,
        },
        queryHandler: SASTParsedHandler,
        extendStore: (notesStore) => {
          Object.assign(notesStore.getters, {
            'diffs/flatBlobsList': [{ type: 'blob', fileHash: '123' }],
            'diffs/isVirtualScrollingEnabled': false,
            'diffs/diffFiles': [{ file_hash: '123' }],
          });
        },
      });

      await waitForPromises();

      expect(wrapper.findComponent(DiffFile).props('sastData')).toEqual(SAST_REPORT_DATA);
    });
  });
});
