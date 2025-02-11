import { GlCard, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import DuoConfigurationSettingsInfoCard from 'ee/ai/settings/components/duo_configuration_settings_info_card.vue';
import DuoConfigurationSettingsRow from 'ee/ai/settings/components/duo_configuration_settings_row.vue';

jest.mock('~/lib/utils/url_utility');

describe('DuoConfigurationSettingsInfoCard', () => {
  let wrapper;

  const createComponent = ({
    duoConfigurationPath = '/gitlab_duo/configuration',
    isSaaS = false,
    isStandalonePage = false,
    duoAvailability = AVAILABILITY_OPTIONS.DEFAULT_ON,
    directCodeSuggestionsEnabled = true,
    experimentFeaturesEnabled = true,
    betaSelfHostedModelsEnabled = true,
    areExperimentSettingsAllowed = true,
  } = {}) => {
    wrapper = shallowMountExtended(DuoConfigurationSettingsInfoCard, {
      provide: {
        duoConfigurationPath,
        isSaaS,
        isStandalonePage,
        duoAvailability,
        directCodeSuggestionsEnabled,
        experimentFeaturesEnabled,
        betaSelfHostedModelsEnabled,
        areExperimentSettingsAllowed,
      },
    });
  };

  const findCard = () => wrapper.findAllComponents(GlCard);
  const findConfigurationButton = () => wrapper.findComponent(GlButton);
  const findDuoConfigurationRows = () => wrapper.findAllComponents(DuoConfigurationSettingsRow);
  const findDuoConfigurationRowTitlePropByRowIdx = (idx) =>
    findDuoConfigurationRows().at(idx).props('duoConfigurationSettingsRowTypeTitle');
  const findDuoConfigurationSettingsInfo = () =>
    wrapper.findByTestId('duo-configuration-settings-info');
  const findConfigurationStatus = () => wrapper.findByTestId('configuration-status');

  describe('on component loaded', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the GlCard component', () => {
      expect(findCard().exists()).toBe(true);
    });

    it('renders the title correctly', () => {
      expect(findDuoConfigurationSettingsInfo().text()).toBe('GitLab Duo');
    });

    it('renders the configuration button with correct href', () => {
      expect(findConfigurationButton().exists()).toBe(true);
      expect(findConfigurationButton().attributes('href')).toBe('/gitlab_duo/configuration');
      expect(findConfigurationButton().text()).toBe('Change configuration');
    });
  });

  describe('availability status', () => {
    it.each([
      [AVAILABILITY_OPTIONS.DEFAULT_ON, 'On by default'],
      [AVAILABILITY_OPTIONS.DEFAULT_OFF, 'Off by default'],
      [AVAILABILITY_OPTIONS.NEVER_ON, 'Always off'],
    ])('displays correct status for %s', (status, expected) => {
      createComponent({ duoAvailability: status });
      expect(findConfigurationStatus().text()).toBe(expected);
    });
  });

  describe('DuoConfigurationSettingsRow rendering', () => {
    it('renders all rows for self-managed instance', () => {
      createComponent({ isSaaS: false });

      expect(findDuoConfigurationRows()).toHaveLength(3);
      expect(findDuoConfigurationRowTitlePropByRowIdx(0)).toEqual('Experiment and beta features');
      expect(findDuoConfigurationRowTitlePropByRowIdx(1)).toEqual('Direct connections');
      expect(findDuoConfigurationRowTitlePropByRowIdx(2)).toEqual('Beta self-hosted models');
    });

    it('renders fewer rows for SaaS instance', () => {
      createComponent({ isSaaS: true });

      expect(findDuoConfigurationRows()).toHaveLength(1);
      expect(findDuoConfigurationRowTitlePropByRowIdx(0)).toEqual('Experiment and beta features');
    });

    it('passes correct props to configuration rows', () => {
      createComponent();
      expect(findDuoConfigurationRows().at(0).props('isEnabled')).toBe(true);
      expect(findDuoConfigurationRows().at(1).props('isEnabled')).toBe(true);
      expect(findDuoConfigurationRows().at(2).props('isEnabled')).toBe(true);
    });
  });
});
