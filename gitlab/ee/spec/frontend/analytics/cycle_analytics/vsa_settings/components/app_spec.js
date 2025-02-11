import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VSASettingsApp from 'ee/analytics/cycle_analytics/vsa_settings/components/app.vue';
import ValueStreamForm from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form.vue';

describe('Value stream analytics settings app component', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(VSASettingsApp, {
      propsData: {
        isEditing: false,
        ...props,
      },
    });
  };

  const findPageHeader = () => wrapper.findByTestId('vsa-settings-page-header');
  const findValueStreamForm = () => wrapper.findComponent(ValueStreamForm);

  describe.each`
    isEditing | expectedPageHeader
    ${false}  | ${'New value stream'}
    ${true}   | ${'Edit value stream'}
  `('when `isEditing` is `$isEditing`', ({ isEditing, expectedPageHeader }) => {
    beforeEach(() => {
      createComponent({ props: { isEditing } });
    });

    it('renders the correct page header', () => {
      expect(findPageHeader().text()).toBe(expectedPageHeader);
    });

    it('renders the value stream form component correctly', () => {
      expect(findValueStreamForm().props('isEditing')).toBe(isEditing);
    });
  });
});
