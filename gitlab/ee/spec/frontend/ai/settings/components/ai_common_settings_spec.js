import { GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiCommonSettingsForm from 'ee/ai/settings/components/ai_common_settings_form.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

describe('AiCommonSettings', () => {
  let wrapper;

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(AiCommonSettings, {
      propsData: {
        hasParentFormChanged: false,
        isGroup: false,
        ...props,
      },
      provide: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        experimentFeaturesEnabled: false,
        onGeneralSettingsPage: false,
        configurationSettingsPath: '/settings/gitlab_duo',
        showRedirectBanner: false,
        ...provide,
      },
      stubs: {
        GlSprintf: {
          template: `
            <span>
              <slot name="link" v-bind="{ content: $attrs.message }">
              </slot>
            </span>
          `,
          components: {
            GlLink,
          },
        },
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);
  const findGeneralSettingsDescriptionText = () =>
    wrapper.findByTestId('general-settings-subtitle');
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findForm = () => wrapper.findComponent(AiCommonSettingsForm);
  const findMovedSettingsAlert = () => wrapper.findByTestId('duo-moved-settings-alert');
  const findMovedDescriptionText = () =>
    wrapper.findByTestId('duo-moved-settings-alert-description-text');
  const findMovedSettingsLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('renders the AiCommonSettingsForm component', () => {
    expect(findForm().exists()).toBe(true);
  });

  it('emits submit event with correct data when form is submitted via AiCommonSettingsForm component', async () => {
    await findForm().vm.$emit('radio-changed', AVAILABILITY_OPTIONS.DEFAULT_OFF);
    await findForm().vm.$emit('checkbox-changed', true);
    findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });
    const emittedData = wrapper.emitted('submit')[0][0];
    expect(emittedData).toEqual({
      duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
      experimentFeaturesEnabled: true,
    });
  });

  describe('when on general settings page', () => {
    beforeEach(() => {
      createComponent({}, { onGeneralSettingsPage: true });
    });

    it('renders SettingsBlock component', () => {
      expect(findSettingsBlock().exists()).toBe(true);
    });

    it('passes props to settings-block component', () => {
      expect(findSettingsBlock().props()).toEqual({
        defaultExpanded: false,
        id: null,
        title: 'GitLab Duo features',
      });
    });

    describe('when showRedirectBanner is true', () => {
      beforeEach(() => {
        createComponent({}, { onGeneralSettingsPage: true, showRedirectBanner: true });
      });

      it('renders the moved settings alert', () => {
        expect(findMovedSettingsAlert().exists()).toBe(true);
        expect(findMovedSettingsAlert().props('title')).toBe('GitLab Duo settings have moved');
      });

      it('renders the alert with correct link based on group context', () => {
        createComponent(
          { isGroup: true },
          { onGeneralSettingsPage: true, showRedirectBanner: true },
        );
        expect(findMovedDescriptionText().attributes('message')).toContain('Settings > GitLab Duo');
        expect(findMovedSettingsLink().attributes('href')).toBe('/settings/gitlab_duo');
      });

      it('includes the correct path text for non-group context', () => {
        createComponent(
          {},
          {
            configurationSettingsPath: '/admin/gitlab_duo',
            onGeneralSettingsPage: true,
            showRedirectBanner: true,
          },
        );
        expect(findMovedDescriptionText().attributes('message')).toContain(
          'Admin Area > GitLab Duo',
        );
        expect(findMovedSettingsLink().attributes('href')).toBe('/admin/gitlab_duo');
      });

      it('does not render the form component', () => {
        expect(findForm().exists()).toBe(false);
      });

      it('does not render the settings block description text', () => {
        expect(findGeneralSettingsDescriptionText().exists()).toBe(false);
      });
    });

    describe('when showRedirectBanner is false', () => {
      beforeEach(() => {
        createComponent({}, { onGeneralSettingsPage: true, showRedirectBanner: false });
      });

      it('does not render the moved settings alert', () => {
        expect(findMovedSettingsAlert().exists()).toBe(false);
      });

      it('renders the settings block description text', () => {
        expect(findGeneralSettingsDescriptionText().exists()).toBe(true);
        expect(findGeneralSettingsDescriptionText().text()).toContain(
          'Configure AI-powered GitLab Duo features',
        );
      });
    });
  });

  describe('when not on general settings page', () => {
    beforeEach(() => {
      createComponent({}, { onGeneralSettingsPage: false });
    });

    it('renders PageHeading component', () => {
      expect(findPageHeading().exists()).toBe(true);
    });

    it('renders correct title in PageHeading', () => {
      expect(findPageHeading().props('heading')).toBe('Configuration');
    });

    it('renders correct subtitle in PageHeading', () => {
      expect(wrapper.findByTestId('configuration-page-subtitle').exists()).toBe(true);
    });
  });
});
