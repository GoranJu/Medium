import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { HTTP_STATUS_NOT_FOUND, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import {
  i18n,
  ERRORS,
} from 'ee/analytics/cycle_analytics/components/create_value_stream_form/constants';
import CustomStageEventLabelField from 'ee/analytics/cycle_analytics/components/create_value_stream_form/custom_stage_event_label_field.vue';
import createStore from 'ee/analytics/cycle_analytics/store';
import { groupLabels as defaultGroupLabels } from '../../mock_data';

Vue.use(Vuex);

const index = 0;
const eventType = 'start-event';
const fieldLabel = i18n.FORM_FIELD_START_EVENT_LABEL;
const labelError = ERRORS.INVALID_EVENT_PAIRS;
const [selectedLabel] = defaultGroupLabels;

const defaultProps = {
  index,
  eventType,
  fieldLabel,
  requiresLabel: true,
};

describe('CustomStageEventLabelField', () => {
  let axiosMock;
  let resolveGroupLabelsRequest;

  function createComponent({ props = {} } = {}) {
    return shallowMountExtended(CustomStageEventLabelField, {
      store: createStore(),
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  }

  let wrapper = null;

  const findEventLabelField = () =>
    wrapper.findByTestId(`custom-stage-${eventType}-label-${index}`);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findToggleButton = () => wrapper.findByTestId('listbox-toggle-btn');

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);

    const endpointResponse = new Promise((resolve) => {
      resolveGroupLabelsRequest = ({
        status = HTTP_STATUS_OK,
        results = defaultGroupLabels,
      } = {}) => {
        resolve([status, results]);
        return waitForPromises();
      };
    });

    axiosMock.onGet().reply(() => endpointResponse);
  });

  afterEach(() => {
    axiosMock.restore();
  });

  describe('Label listbox', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the form group', () => {
      expect(findEventLabelField().attributes()).toMatchObject({
        label: fieldLabel,
        state: 'true',
        'invalid-feedback': '',
      });

      expect(findToggleButton().classes()).not.toContain('gl-shadow-inner-1-red-500');
    });

    it('renders with no selected label', () => {
      expect(findCollapsibleListbox().props().selected).toBeNull();
    });

    it('emits the `update-label` event when a label is selected', () => {
      expect(wrapper.emitted('update-label')).toBeUndefined();

      findCollapsibleListbox().vm.$emit('select', selectedLabel.id);

      expect(wrapper.emitted('update-label').length).toBe(1);
      expect(wrapper.emitted('update-label')[0]).toEqual([{ id: selectedLabel.id }]);
    });
  });

  describe('with selected label', () => {
    beforeEach(() => {
      wrapper = createComponent({ props: { selectedLabelId: selectedLabel.id } });
    });

    it('sets the selected label', () => {
      expect(findCollapsibleListbox().props().selected).toBe(selectedLabel.id);
    });
  });

  describe('with no default labels', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('will show loading state while request is pending', () => {
      expect(findToggleButton().props().loading).toBe(true);
    });

    describe('once labels are loaded', () => {
      beforeEach(() => {
        return resolveGroupLabelsRequest();
      });

      it('stops the loading state', () => {
        expect(findToggleButton().props().loading).toBe(false);
      });

      it('shows the labels in the listbox', () => {
        expect(findCollapsibleListbox().props().items.length).toBe(defaultGroupLabels.length);
      });
    });
  });

  describe('default labels fail to load', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('will show loading state while request is pending', () => {
      expect(findToggleButton().props().loading).toBe(true);
    });

    describe('once request fails', () => {
      beforeEach(() => {
        return resolveGroupLabelsRequest({ status: HTTP_STATUS_NOT_FOUND });
      });

      it('stops the loading state', () => {
        expect(findToggleButton().props().loading).toBe(false);
      });

      it('emits an error', () => {
        expect(wrapper.emitted('error').length).toBe(1);
        expect(wrapper.emitted('error')[0]).toEqual([
          'There was an error fetching label data for the selected group',
        ]);
      });
    });
  });

  describe('when searching', () => {
    const results = defaultGroupLabels.slice(0, 1);

    beforeEach(() => {
      wrapper = createComponent();
      findCollapsibleListbox().vm.$emit('search', 'query');
    });

    it('will show searching state while request is pending', () => {
      expect(findCollapsibleListbox().props().searching).toBe(true);
    });

    describe('once request finishes', () => {
      beforeEach(() => {
        return resolveGroupLabelsRequest({ results });
      });

      it('stops the loading state', () => {
        expect(findCollapsibleListbox().props().searching).toBe(false);
      });

      it('shows the labels in the listbox', () => {
        expect(findCollapsibleListbox().props().items.length).toBe(results.length);
      });
    });
  });

  describe('with `requiresLabel=false`', () => {
    beforeEach(() => {
      wrapper = createComponent({ props: { requiresLabel: false } });
    });

    it('sets the form group error state', () => {
      expect(findEventLabelField().exists()).toBe(false);
    });
  });

  describe('with an event field error', () => {
    beforeEach(() => {
      wrapper = createComponent({
        props: {
          isLabelValid: false,
          labelError,
        },
      });
    });

    it('sets the form group error state', () => {
      expect(findEventLabelField().attributes('state')).toBeUndefined();
      expect(findEventLabelField().attributes('invalid-feedback')).toBe(labelError);
    });

    it('sets the listbox toggle button error state', () => {
      expect(findToggleButton().classes()).toContain('gl-shadow-inner-1-red-500');
    });
  });
});
