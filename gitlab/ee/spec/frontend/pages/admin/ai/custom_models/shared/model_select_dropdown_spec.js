import { mount } from '@vue/test-utils';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import ModelSelectDropdown from 'ee/pages/admin/ai/custom_models/shared/model_select_dropdown.vue';
import { listItems, featureSettingsListItems } from './mock_data';

describe('ModelSelectDropdown', () => {
  let wrapper;

  const dropdownToggleText = 'Select model';
  const selectedOption = listItems[0];

  const createComponent = ({ props = {} } = {}) => {
    wrapper = extendedWrapper(
      mount(ModelSelectDropdown, {
        propsData: {
          items: listItems,
          dropdownToggleText,
          selectedOption,
          ...props,
        },
      }),
    );
  };

  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);
  const findGLCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownListItems = () => wrapper.findAllByRole('option');
  const findAddModelButton = () => wrapper.findByTestId('add-self-hosted-model-button');
  const findDropdownToggleText = () => wrapper.findByTestId('dropdown-toggle-text');
  const findToggleBetaBadge = () => wrapper.findByTestId('toggle-beta-badge');

  it('renders the component', () => {
    createComponent();

    expect(findModelSelectDropdown().exists()).toBe(true);
  });

  it('renders the dropdown toggle text', () => {
    createComponent();

    expect(findDropdownToggleText().text()).toBe('Select model');
  });

  describe('list items', () => {
    it('renders list items', () => {
      createComponent();

      expect(findGLCollapsibleListbox().props('items')).toBe(listItems);
    });

    it('can handle feature settings list items', () => {
      createComponent({ props: { items: featureSettingsListItems } });

      expect(findGLCollapsibleListbox().props('items')).toBe(featureSettingsListItems);
      expect(findDropdownListItems().at(5).text()).toEqual('Disable');
      expect(findDropdownListItems().at(6).text()).toEqual('GitLab AI Vendor');
    });
  });

  describe('when isLoading is true', () => {
    it('renders the loading state', () => {
      createComponent({ props: { isLoading: true } });

      expect(findGLCollapsibleListbox().props('loading')).toBe(true);
    });
  });

  describe('when isFeatureSettingDropdown is true', () => {
    beforeEach(() => {
      createComponent({ props: { isFeatureSettingDropdown: true } });
    });

    it('renders compatible models header-text', () => {
      expect(findGLCollapsibleListbox().props('headerText')).toBe('Compatible models');
    });

    it('renders a button to add a self-hosted model', () => {
      expect(findAddModelButton().text()).toBe('Add self-hosted model');
    });
  });

  describe('when isFeatureSettingDropdown is false', () => {
    it('does not render feature setting elements', () => {
      createComponent();

      expect(findGLCollapsibleListbox().props('headerText')).toBe(null);
      expect(findAddModelButton().exists()).toBe(false);
    });
  });

  describe('when there are beta models', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays a beta badge with beta options in the dropdown', () => {
      const betaModelOption = findDropdownListItems().at(1);

      expect(betaModelOption.text()).toMatch('Code Llama');
      expect(betaModelOption.find('.gl-badge-content').text()).toMatch('Beta');
    });

    it('displays a beta badge with a selected beta option', () => {
      const selectedBetaModel = listItems[1];

      createComponent({ props: { selectedOption: selectedBetaModel } });

      expect(findToggleBetaBadge().exists()).toBe(true);
    });
  });
});
