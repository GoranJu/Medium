import { GlCollapsibleListbox } from '@gitlab/ui';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TasksByTypeFilters from 'ee/analytics/cycle_analytics/components/tasks_by_type/filters.vue';
import {
  TASKS_BY_TYPE_SUBJECT_ISSUE,
  TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST,
} from 'ee/analytics/cycle_analytics/constants';
import createStore from 'ee/analytics/cycle_analytics/store';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert, VARIANT_INFO } from '~/alert';
import { HTTP_STATUS_NOT_FOUND, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { groupLabels, groupLabelNames } from '../../mock_data';

Vue.use(Vuex);

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

describe('TasksByTypeFilters', () => {
  let wrapper = null;

  const mockGroupLabelsRequest = ({ status = HTTP_STATUS_OK, results = groupLabels } = {}) =>
    new MockAdapter(axios).onGet().reply(status, results);

  const createWrapper = async ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(TasksByTypeFilters, {
      store: createStore(),
      propsData: {
        selectedLabelNames: groupLabelNames,
        subjectFilter: TASKS_BY_TYPE_SUBJECT_ISSUE,
        ...props,
      },
    });

    await waitForPromises();
  };

  const findSubjectFilters = () => wrapper.findComponentByTestId('type-of-work-filters-subject');
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSelectedLabelsCount = () => wrapper.findByTestId('selected-labels-count');

  describe('with default props', () => {
    beforeEach(() => {
      mockGroupLabelsRequest();
      return createWrapper();
    });

    it('has the issue subject set by default', () => {
      expect(findSubjectFilters().props().value).toBe(TASKS_BY_TYPE_SUBJECT_ISSUE);
    });

    it('emits the `set-subject` event when a subject filter is clicked', () => {
      expect(wrapper.emitted('set-subject')).toBeUndefined();

      findSubjectFilters().vm.$emit('input', TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST);

      expect(wrapper.emitted('set-subject').length).toBe(1);
      expect(wrapper.emitted('set-subject')[0][0]).toEqual(TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST);
    });

    it('emits the `toggle-label` event when a label is selected', () => {
      expect(wrapper.emitted('toggle-label')).toBeUndefined();

      findCollapsibleListbox().vm.$emit('select', groupLabels[0].title);

      expect(wrapper.emitted('toggle-label').length).toBe(1);
      expect(wrapper.emitted('toggle-label')[0][0]).toEqual(groupLabels[0]);
      expect(mockAlertDismiss).not.toHaveBeenCalled();
    });

    it('renders the count of currently selected labels', () => {
      expect(findSelectedLabelsCount().text()).toBe('3 labels selected (15 max)');
    });
  });

  describe('with no labels selected', () => {
    beforeEach(() => {
      mockGroupLabelsRequest();
      return createWrapper({ props: { selectedLabelNames: [] } });
    });

    it('does not render the count of currently selected labels', () => {
      expect(findSelectedLabelsCount().exists()).toBe(false);
    });
  });

  describe('with one label selected', () => {
    beforeEach(() => {
      mockGroupLabelsRequest();
      return createWrapper({ props: { selectedLabelNames: [groupLabels[0].title] } });
    });

    it('renders the count of currently selected labels', () => {
      expect(findSelectedLabelsCount().text()).toBe('1 label selected (15 max)');
    });
  });

  describe('with maximum labels selected', () => {
    const selectedLabelNames = [groupLabels[0].title, groupLabels[1].title];

    beforeEach(() => {
      mockGroupLabelsRequest();
      return createWrapper({ props: { maxLabels: 2, selectedLabelNames } });
    });

    it('should not allow adding a label', () => {
      findCollapsibleListbox().vm.$emit('select', [...selectedLabelNames, groupLabels[2].title]);
      expect(wrapper.emitted('toggle-label')).toBeUndefined();
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Only 2 labels can be selected at this time',
        variant: VARIANT_INFO,
      });
      expect(mockAlertDismiss).not.toHaveBeenCalled();
    });

    it('should allow removing a label', () => {
      findCollapsibleListbox().vm.$emit('select', [groupLabels[0].title]);
      expect(wrapper.emitted('toggle-label').length).toBe(1);
      expect(wrapper.emitted('toggle-label')[0][0]).toEqual(groupLabels[1]);
    });

    it('should dismiss maximum labels alert upon removing a label', () => {
      findCollapsibleListbox().vm.$emit('select', [...selectedLabelNames, groupLabels[2].title]);
      expect(createAlert).toHaveBeenCalled();

      findCollapsibleListbox().vm.$emit('select', [groupLabels[0].title]);
      expect(mockAlertDismiss).toHaveBeenCalled();
    });
  });

  describe('with no default labels', () => {
    beforeEach(() => {
      mockGroupLabelsRequest();
      createWrapper({ state: { defaultGroupLabels: [] } });
    });

    it('will show loading state while request is pending', () => {
      expect(findCollapsibleListbox().props().loading).toBe(true);
    });

    describe('once labels are loaded', () => {
      beforeEach(() => {
        return waitForPromises();
      });

      it('stops the loading state', () => {
        expect(findCollapsibleListbox().props().loading).toBe(false);
      });

      it('shows the labels in the listbox', () => {
        expect(findCollapsibleListbox().props().items.length).toBe(groupLabels.length);
      });
    });
  });

  describe('default labels fail to load', () => {
    beforeEach(() => {
      mockGroupLabelsRequest({ status: HTTP_STATUS_NOT_FOUND });
      return createWrapper({ state: { defaultGroupLabels: [] } });
    });

    it('stops the loading state', () => {
      expect(findCollapsibleListbox().props().loading).toBe(false);
    });

    it('emits an error', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching label data for the selected group',
      });
    });
  });

  describe('when searching', () => {
    const results = groupLabels.slice(0, 1);

    beforeEach(async () => {
      mockGroupLabelsRequest({ results });
      await createWrapper();

      findCollapsibleListbox().vm.$emit('search', 'query');
    });

    it('will show searching state while request is pending', () => {
      expect(findCollapsibleListbox().props().searching).toBe(true);
    });

    describe('once request finishes', () => {
      beforeEach(() => {
        return waitForPromises();
      });

      it('stops the loading state', () => {
        expect(findCollapsibleListbox().props().searching).toBe(false);
      });

      it('shows the labels in the listbox', () => {
        expect(findCollapsibleListbox().props().items.length).toBe(results.length);
      });
    });
  });
});
