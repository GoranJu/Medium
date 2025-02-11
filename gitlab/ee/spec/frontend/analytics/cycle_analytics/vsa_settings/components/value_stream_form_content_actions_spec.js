import ValueStreamFormContentHeader from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content_actions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { valueStreamPath } from '../../mock_data';

describe('ValueStreamFormContentActions', () => {
  let wrapper;

  const findPrimaryBtn = () => wrapper.findByTestId('primary-button');
  const findValueStreamCancelBtn = () => wrapper.findByTestId('cancel-button');
  const findAddStageBtn = () => wrapper.findByTestId('add-button');

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(ValueStreamFormContentHeader, {
      propsData: {
        valueStreamPath,
        ...props,
      },
    });
  };

  describe.each`
    isEditing | text
    ${false}  | ${'New value stream'}
    ${true}   | ${'Save value stream'}
  `('when `isEditing` is `$isEditing`', ({ isEditing, text }) => {
    beforeEach(() => {
      createComponent({ props: { isEditing } });
    });

    it('renders primary action correctly', () => {
      expect(findPrimaryBtn().text()).toBe(text);
      expect(findPrimaryBtn().props()).toMatchObject({
        variant: 'confirm',
        loading: false,
        disabled: false,
      });
    });

    it('emits `clickPrimaryAction` event when primary action is selected', () => {
      findPrimaryBtn().vm.$emit('click');

      expect(wrapper.emitted('clickPrimaryAction')).toHaveLength(1);
    });

    it('renders add stage action correctly', () => {
      expect(findAddStageBtn().props()).toMatchObject({
        category: 'secondary',
        variant: 'confirm',
        disabled: false,
      });
    });

    it('emits `clickAddStageAction` event when add stage action is selected', () => {
      findAddStageBtn().vm.$emit('click');

      expect(wrapper.emitted('clickAddStageAction')).toHaveLength(1);
    });

    it('renders cancel button link correctly', () => {
      expect(findValueStreamCancelBtn().props('disabled')).toBe(false);
      expect(findValueStreamCancelBtn().attributes('href')).toBe(valueStreamPath);
    });

    describe('isLoading=true', () => {
      beforeEach(() => {
        createComponent({ props: { isEditing, isLoading: true } });
      });

      it('sets primary action to a loading state', () => {
        expect(findPrimaryBtn().props('loading')).toBe(true);
      });

      it('disables all other actions', () => {
        expect(findAddStageBtn().props('disabled')).toBe(true);
        expect(findValueStreamCancelBtn().props('disabled')).toBe(true);
      });
    });
  });
});
