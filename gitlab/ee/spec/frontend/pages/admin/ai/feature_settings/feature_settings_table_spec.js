import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import FeatureSettingsTable from 'ee/pages/admin/ai/feature_settings/components/feature_settings_table.vue';
import getAiFeatureSettingsQuery from 'ee/pages/admin/ai/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import getCurrentLicense from 'ee/admin/subscriptions/show/graphql/queries/get_current_license.query.graphql';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { license } from 'ee_jest/admin/subscriptions/show/mock_data';
import { mockAiFeatureSettings } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('FeatureSettingsTable', () => {
  let wrapper;

  const getAiFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettings: {
        nodes: mockAiFeatureSettings,
        errors: [],
      },
    },
  });

  const getCurrentLicenseSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      currentLicense: {
        ...license.ULTIMATE,
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [
      [getAiFeatureSettingsQuery, getAiFeatureSettingsSuccessHandler],
      [getCurrentLicense, getCurrentLicenseSuccessHandler],
    ],
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = mountExtended(FeatureSettingsTable, {
      apolloProvider: mockApollo,
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableHeaders = () => findTable().findAllComponents('th');
  const findTableRows = () => findTable().findAllComponents('tbody > tr');
  const findLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  it('renders the table component', () => {
    createComponent();

    expect(findTable().exists()).toBe(true);
  });

  it('renders table headers <th>', () => {
    const expectedTableHeaderNames = ['Main feature', 'Sub feature', 'Model name'];

    createComponent();

    expect(findTableHeaders().wrappers.map((h) => h.text())).toEqual(expectedTableHeaderNames);
  });

  describe('when feature settings data is loading', () => {
    it('renders skeleton loaders', () => {
      createComponent();

      expect(findLoaders().exists()).toBe(true);
    });
  });

  describe('when the API query is successful', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders Code Suggestions sub-features', () => {
      const rows = findTableRows().wrappers.map((h) => h.text());

      expect(rows.filter((r) => r.includes('Code Generation')).length).toEqual(1);
      expect(rows.filter((r) => r.includes('Code Completion')).length).toEqual(1);
    });

    it('renders Duo Chat', () => {
      const rows = findTableRows().wrappers.map((h) => h.text());

      expect(rows.filter((r) => r.includes('Duo Chat')).length).toEqual(1);
    });
  });

  describe('when the API request is unsuccessful', () => {
    describe('due to a general error', () => {
      it('displays an error message for feature settings', async () => {
        createComponent({
          apolloHandlers: [
            [getAiFeatureSettingsQuery, jest.fn().mockRejectedValue('ERROR')],
            [getCurrentLicense, getCurrentLicenseSuccessHandler],
          ],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the AI feature settings. Please try again.',
          }),
        );
      });

      it('displays an error message for the license', async () => {
        createComponent({
          apolloHandlers: [
            [getAiFeatureSettingsQuery, getAiFeatureSettingsSuccessHandler],
            [getCurrentLicense, jest.fn().mockRejectedValue('ERROR')],
          ],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the current license. Please try again.',
          }),
        );
      });
    });

    describe('due to a business logic error', () => {
      const getAiFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiFeatureSettings: {
            errors: ['An error occured'],
          },
        },
      });

      it('displays an error message for feature settings', async () => {
        createComponent({
          apolloHandlers: [
            [getAiFeatureSettingsQuery, getAiFeatureSettingsErrorHandler],
            [getCurrentLicense, getCurrentLicenseSuccessHandler],
          ],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the AI feature settings. Please try again.',
          }),
        );
      });
    });
  });
});
