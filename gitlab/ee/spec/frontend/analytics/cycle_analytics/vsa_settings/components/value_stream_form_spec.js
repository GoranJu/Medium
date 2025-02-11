import Vue from 'vue';
import { GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import ValueStreamForm from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form.vue';
import ValueStreamFormContent from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  rawCustomStage,
  valueStreams,
  defaultStageConfig,
  vsaPath,
  valueStreamPath,
  groupLabels as defaultGroupLabels,
} from 'ee_jest/analytics/cycle_analytics/mock_data';

Vue.use(Vuex);

const [selectedValueStream] = valueStreams;
const camelCustomStage = convertObjectPropsToCamelCase(rawCustomStage);
const stages = [camelCustomStage];
const initialData = { name: '', stages: [] };

const fetchGroupLabelsMock = jest.fn(() => Promise.resolve());

describe('ValueStreamForm', () => {
  let wrapper = null;

  const fakeStore = ({ state }) =>
    new Vuex.Store({
      state: {
        createValueStreamErrors: {},
        defaultStageConfig,
        defaultGroupLabels,
        isLoading: false,
        isFetchingGroupLabels: false,
        isFetchingGroupStagesAndEvents: false,
        ...state,
      },
      actions: {
        fetchGroupLabels: fetchGroupLabelsMock,
      },
    });

  const createComponent = ({ props = {}, state = {} } = {}) => {
    wrapper = shallowMountExtended(ValueStreamForm, {
      store: fakeStore({ state }),
      propsData: {
        defaultStageConfig,
        ...props,
      },
      provide: {
        vsaPath,
      },
    });
  };

  const findFormContent = () => wrapper.findComponent(ValueStreamFormContent);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  describe('default state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the form content component', () => {
      expect(findFormContent().props()).toMatchObject({
        defaultStageConfig,
        initialData,
        isEditing: false,
        valueStreamPath: vsaPath,
      });
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('when editing', () => {
    beforeEach(() => {
      createComponent({
        props: { isEditing: true },
        state: { selectedValueStream, stages },
      });
    });

    it('renders form content component correctly', () => {
      const populatedInitialData = {
        id: selectedValueStream.id,
        name: selectedValueStream.name,
        stages: [
          camelCustomStage,
          ...defaultStageConfig.map(({ custom, name }) => ({ custom, name, hidden: true })),
        ],
      };

      expect(findFormContent().props()).toMatchObject({
        defaultStageConfig,
        initialData: populatedInitialData,
        isEditing: true,
        valueStreamPath,
      });
    });
  });

  describe.each(['isLoading', 'isFetchingGroupStagesAndEvents', 'isFetchingGroupLabels'])(
    'when %s',
    (isFetchingResource) => {
      beforeEach(() => {
        createComponent({ state: { [isFetchingResource]: true } });
      });

      it('renders loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('does not render form content component', () => {
        expect(findFormContent().exists()).toBe(false);
      });
    },
  );

  describe('with createValueStreamErrors', () => {
    const nameError = "Name can't be blank";
    beforeEach(() => {
      createComponent({
        state: { createValueStreamErrors: { name: nameError } },
      });
    });

    it(`sets the form content component's initialFormErrors prop`, () => {
      expect(findFormContent().props('initialFormErrors')).toEqual({ name: nameError });
    });
  });

  describe('when there are no defaultGroupLabels', () => {
    beforeEach(() => {
      createComponent({
        state: { defaultGroupLabels: null },
      });
    });

    it('should fetch group labels', () => {
      expect(fetchGroupLabelsMock).toHaveBeenCalledTimes(1);
    });
  });
});
