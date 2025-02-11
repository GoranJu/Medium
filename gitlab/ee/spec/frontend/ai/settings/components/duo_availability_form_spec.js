import { shallowMount } from '@vue/test-utils';
import { GlFormRadio } from '@gitlab/ui';
import DuoAvailabilityForm from 'ee/ai/settings/components/duo_availability_form.vue';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

describe('DuoAvailabilityForm', () => {
  let wrapper;

  const createComponent = (props = {}, provide = {}) => {
    return shallowMount(DuoAvailabilityForm, {
      propsData: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        ...props,
      },
      provide: {
        areDuoSettingsLocked: false,
        cascadingSettingsData: {
          lockedByAncestor: false,
          lockedByApplicationSetting: false,
          ancestorNamespace: null,
        },
        ...provide,
      },
    });
  };

  const findFormRadioButtons = () => wrapper.findAllComponents(GlFormRadio);
  const findCascadingLockIcon = () => wrapper.findComponent(CascadingLockIcon);

  it('renders radio buttons with correct labels', () => {
    wrapper = createComponent();
    expect(findFormRadioButtons()).toHaveLength(3);
    expect(findFormRadioButtons().at(0).text()).toContain('On by default');
    expect(findFormRadioButtons().at(1).text()).toContain('Off by default');
    expect(findFormRadioButtons().at(2).text()).toContain('Always off');
  });

  it('emits change event when radio button is selected', () => {
    wrapper = createComponent();
    findFormRadioButtons().at(1).vm.$emit('change');
    expect(findFormRadioButtons().at(1).attributes('value')).toBe(AVAILABILITY_OPTIONS.DEFAULT_OFF);
  });

  describe('when areDuoSettingsLocked is true', () => {
    beforeEach(() => {
      wrapper = createComponent(
        {},
        {
          areDuoSettingsLocked: true,
        },
      );
    });

    it('disables radio buttons', () => {
      const radios = wrapper.findAllComponents(GlFormRadio);
      radios.wrappers.forEach((radio) => {
        expect(radio.attributes().disabled).toBe('true');
      });
    });

    it('shows CascadingLockIcon when cascadingSettingsData is provided', () => {
      expect(findCascadingLockIcon().exists()).toBe(true);
    });

    it('passes correct props to CascadingLockIcon', () => {
      expect(findCascadingLockIcon().props()).toMatchObject({
        isLockedByGroupAncestor: false,
        isLockedByApplicationSettings: false,
        ancestorNamespace: null,
      });
    });

    it('does not show CascadingLockIcon when cascadingSettingsData is empty', () => {
      wrapper = createComponent(
        {},
        {
          cascadingSettingsData: {},
        },
      );
      expect(findCascadingLockIcon().exists()).toBe(false);
    });

    it('does not show CascadingLockIcon when cascadingSettingsData is null', () => {
      wrapper = createComponent(
        {},
        {
          cascadingSettingsData: null,
        },
      );
      expect(findCascadingLockIcon().exists()).toBe(false);
    });
  });

  describe('when areDuoSettingsLocked is false', () => {
    it('does not show CascadingLockIcon', () => {
      wrapper = createComponent();
      expect(findCascadingLockIcon().exists()).toBe(false);
    });
  });
});
