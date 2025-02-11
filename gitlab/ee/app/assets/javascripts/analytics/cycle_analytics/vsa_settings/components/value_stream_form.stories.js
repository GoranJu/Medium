import { withVuexStore } from 'storybook_addons/vuex_store';
import {
  defaultStageConfig,
  defaultGroupLabels,
  formEvents,
  selectedValueStream,
  selectedValueStreamStages,
  formSubmissionErrors as createValueStreamErrors,
} from 'ee/analytics/cycle_analytics/vsa_settings/components/stories_constants';
import ValueStreamForm from './value_stream_form.vue';

export default {
  component: ValueStreamForm,
  title: 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form',
  decorators: [withVuexStore],
};

const createStoryWithState = ({ state = {} } = {}) => {
  return (args, { argTypes, createVuexStore }) => ({
    components: { ValueStreamForm },
    provide: {
      vsaPath: '',
    },
    props: Object.keys(argTypes),
    template: '<value-stream-form v-bind="$props" />',
    store: createVuexStore({
      state: {
        defaultStageConfig,
        formEvents,
        defaultGroupLabels,
        isLoading: false,
        ...state,
      },
      actions: {
        fetchGroupLabels: () => true,
      },
    }),
  });
};

export const Default = {
  render: createStoryWithState(),
};

export const EditValueStream = {
  render: createStoryWithState({
    state: {
      selectedValueStream,
      stages: selectedValueStreamStages(),
    },
  }),
  args: {
    isEditing: true,
  },
};

export const EditValueStreamWithCustomStages = {
  render: createStoryWithState({
    state: {
      selectedValueStream,
      stages: selectedValueStreamStages({ addCustomStage: true }),
    },
  }),
  args: {
    isEditing: true,
  },
};

export const EditValueStreamWithHiddenStages = {
  render: createStoryWithState({
    state: {
      selectedValueStream,
      stages: selectedValueStreamStages({ addCustomStage: true, hideStages: true }),
    },
  }),
  args: {
    isEditing: true,
  },
};

export const SavingNewValueStream = {
  render: createStoryWithState({
    state: {
      isCreatingValueStream: true,
    },
  }),
};

export const UpdatingValueStream = {
  render: createStoryWithState({
    state: {
      selectedValueStream,
      stages: selectedValueStreamStages(),
      isEditingValueStream: true,
    },
  }),
  args: {
    isEditing: true,
  },
};

export const WithFormSubmissionErrors = {
  render: createStoryWithState({
    state: {
      selectedValueStream,
      stages: selectedValueStreamStages({ addCustomStage: true }),
      createValueStreamErrors,
    },
  }),
  args: {
    isEditing: true,
  },
};

export const Loading = {
  render: createStoryWithState({
    state: {
      isLoading: true,
    },
  }),
};
