import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoConfigurationSettingsRow from 'ee/ai/settings/components/duo_configuration_settings_row.vue';

describe('DuoConfigurationSettingsRow', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DuoConfigurationSettingsRow, {
      propsData: {
        duoConfigurationSettingsRowTypeTitle: 'Duo Row Title',
        isEnabled: false,
        ...props,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findConfigurationStatus = () => wrapper.findByTestId('duo-configuration-row-title');
  const findConfigurationEnabled = () => wrapper.findByTestId('duo-configuration-row-enabled-text');
  const findConfigurationDisabled = () =>
    wrapper.findByTestId('duo-configuration-row-disabled-text');

  describe('component rendering', () => {
    it('renders the title correctly', () => {
      createComponent();
      expect(findConfigurationStatus().text()).toBe('Duo Row Title');
    });

    describe('when enabled', () => {
      beforeEach(() => {
        createComponent({ isEnabled: true });
      });

      it('displays the enabled text', () => {
        expect(findConfigurationEnabled().text()).toBe('Enabled');
      });

      it('renders the check icon', () => {
        expect(findIcon().exists()).toBe(true);
      });
    });

    describe('when disabled', () => {
      beforeEach(() => {
        createComponent({ isEnabled: false });
      });

      it('displays the disabled text', () => {
        expect(findConfigurationDisabled().text()).toBe('Not enabled');
      });

      it('does not render the check icon', () => {
        expect(findIcon().exists()).toBe(false);
      });
    });
  });
});
