import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import SelfHostedDuoConfiguration from 'ee/pages/admin/ai/custom_models/self_hosted_duo_configuration.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('SelfHostedDuoConfiguration', () => {
  let wrapper;
  const $router = { push: jest.fn() };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(SelfHostedDuoConfiguration, {
      propsData: {
        ...props,
      },
      mocks: {
        $router,
        $route: { params: {} },
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findTabs = () => wrapper.findByTestId('self-hosted-duo-config-tabs');
  const findFeatureSettingsTab = () => wrapper.findByTestId('ai-feature-settings-tab');
  const findSelfHostedModelsTab = () => wrapper.findByTestId('self-hosted-models-tab');
  const findAddModelButton = () => wrapper.findComponent(GlButton);

  it('has a title', () => {
    const title = wrapper.findByTestId('self-hosted-title');

    expect(title.text()).toBe('Self-hosted models');
  });

  it('has a description', () => {
    expect(wrapper.text()).toMatch(
      'Manage GitLab Duo by configuring and assigning self-hosted models to AI-powered features.',
    );
  });

  it('has a button to add a new self-hosted model', () => {
    expect(findAddModelButton().text()).toBe('Add self-hosted model');
  });

  describe('Self-hosted models tab', () => {
    it('renders the correct name', () => {
      expect(findSelfHostedModelsTab().text()).toBe('Self-hosted models');
    });

    it('navigates to self-hosted models when tab is clicked', async () => {
      createComponent({ props: { tabId: 'ai-feature-settings' } });

      findTabs().vm.$emit('input', 0);

      await nextTick();

      expect($router.push).toHaveBeenCalledWith({ name: 'index' });
    });
  });

  describe('Feature settings tab', () => {
    it('renders the correct name', () => {
      expect(findFeatureSettingsTab().text()).toBe('AI-powered features');
    });

    it('navigates to feature settings when tab is clicked', async () => {
      findTabs().vm.$emit('input', 1);

      await nextTick();

      expect($router.push).toHaveBeenCalledWith({ name: 'features' });
    });
  });
});
