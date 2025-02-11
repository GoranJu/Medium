import { nextTick } from 'vue';
import { GlLink, GlSprintf, GlForm, GlAlert, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import AmazonQSettingsBlock from 'ee/amazon_q_settings/components/amazon_q_settings_block.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import DuoAvailability from 'ee/ai/settings/components/duo_availability_form.vue';

describe('ee/amazon_q_settings/components/amazon_q_settings_block.vue', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AmazonQSettingsBlock, {
      propsData: {
        initAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        isLoading: false,
        ...props,
      },
      stubs: {
        SettingsBlock: stubComponent(SettingsBlock, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
        GlSprintf,
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);
  const findSettingsBlockDescription = () => wrapper.findByTestId('slot-description');
  const findSettingsBlockDescriptionLink = () =>
    findSettingsBlockDescription().findComponent(GlLink);
  const findForm = () => wrapper.findComponent(GlForm);
  const findDuoAvailabilityInput = () => findForm().findComponent(DuoAvailability);
  const findWarningAlert = () => findForm().findComponent(GlAlert);
  const findSubmitButton = () => findForm().findComponent(GlButton);

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders settings block', () => {
      expect(findSettingsBlock().props('title')).toEqual('Amazon Q');
    });

    it('renders settings block description', () => {
      expect(findSettingsBlockDescription().text()).toEqual(
        'Use GitLab Duo with Amazon Q to create and review merge requests and upgrade Java. GitLab Duo with Amazon Q is separate from GitLab Duo Pro and Enterprise. Learn more.',
      );
      expect(findSettingsBlockDescriptionLink().text()).toEqual('Learn more');
      expect(findSettingsBlockDescriptionLink().attributes('href')).toEqual(
        '/help/user/duo_amazon_q/_index.md',
      );
    });

    it('renders duo availability input', () => {
      expect(findDuoAvailabilityInput().props()).toMatchObject({
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
      });
    });

    it('does not render warning alert', () => {
      expect(findWarningAlert().exists()).toBe(false);
    });

    it('renders submit button', () => {
      expect(findSubmitButton().text()).toEqual('Save changes');
      expect(findSubmitButton().props('loading')).toBe(false);
      expect(findSubmitButton().attributes()).toMatchObject({
        type: 'submit',
        disabled: 'true',
      });
    });

    describe('when value changes to never_on', () => {
      beforeEach(async () => {
        findDuoAvailabilityInput().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);

        await nextTick();
      });

      it('renders warning alert', () => {
        expect(findWarningAlert().props()).toMatchObject({
          dismissible: false,
          variant: 'warning',
        });
        expect(findWarningAlert().text()).toEqual(
          'When you save, Amazon Q will be turned off for all subgroups, and projects, even if they have previously enabled it.This will also remove the Amazon Q service account from these groups and projects.',
        );
      });

      it('enables submit button', () => {
        expect(findSubmitButton().props('disabled')).toBe(false);
      });

      it('emits submit event when form is submitted', async () => {
        expect(wrapper.emitted('submit')).toBeUndefined();

        findForm().vm.$emit('submit', new Event('submit'));
        await nextTick();

        expect(wrapper.emitted('submit')).toEqual([
          [
            {
              availability: AVAILABILITY_OPTIONS.NEVER_ON,
            },
          ],
        ]);
      });
    });
  });

  it('with loading, renders submit button with loading', () => {
    createComponent({ isLoading: true });

    expect(findSubmitButton().props('loading')).toBe(true);
  });
});
