import { GlAlert, GlFormInput } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  PRESET_OPTIONS_BLANK,
  PRESET_OPTIONS_DEFAULT,
} from 'ee/analytics/cycle_analytics/components/create_value_stream_form/constants';
import CustomStageFields from 'ee/analytics/cycle_analytics/components/create_value_stream_form/custom_stage_fields.vue';
import CustomStageEventField from 'ee/analytics/cycle_analytics/components/create_value_stream_form/custom_stage_event_field.vue';
import DefaultStageFields from 'ee/analytics/cycle_analytics/components/create_value_stream_form/default_stage_fields.vue';
import ValueStreamFormContent from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import {
  convertObjectPropsToCamelCase,
  convertObjectPropsToSnakeCase,
} from '~/lib/utils/common_utils';
import ValueStreamFormContentActions from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content_actions.vue';
import {
  customStageEvents as formEvents,
  defaultStageConfig,
  rawCustomStage,
  groupLabels as defaultGroupLabels,
  valueStreamPath,
} from '../../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrlWithAlerts: jest.fn(),
}));

Vue.use(Vuex);

describe('ValueStreamFormContent', () => {
  let wrapper = null;
  let trackingSpy = null;

  const createValueStreamMock = jest.fn(() => Promise.resolve());
  const updateValueStreamMock = jest.fn(() => Promise.resolve());
  const mockToastShow = jest.fn();
  const streamName = 'Cool stream';
  const initialFormNameErrors = { name: ['Name field required'] };
  const initialFormStageErrors = {
    stages: [
      {
        name: ['Name field is required'],
        startEventIdentifier: ['Start event is required'],
      },
    ],
  };
  const formSubmissionErrors = {
    name: ['has already been taken'],
    stages: [
      {
        name: ['has already been taken'],
      },
    ],
  };

  const initialData = {
    stages: [convertObjectPropsToCamelCase(rawCustomStage)],
    id: 1337,
    name: 'Editable value stream',
  };

  const initialPreset = PRESET_OPTIONS_DEFAULT;

  const fakeStore = ({ state }) =>
    new Vuex.Store({
      state: {
        isCreatingValueStream: false,
        isEditingValueStream: false,
        formEvents,
        defaultGroupLabels,
        ...state,
      },
      actions: {
        createValueStream: createValueStreamMock,
        updateValueStream: updateValueStreamMock,
      },
    });

  const createComponent = ({ props = {}, data = {}, stubs = {}, state = {} } = {}) =>
    shallowMountExtended(ValueStreamFormContent, {
      store: fakeStore({ state }),
      data() {
        return {
          ...data,
        };
      },
      propsData: {
        defaultStageConfig,
        valueStreamPath,
        ...props,
      },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
      stubs: {
        ...stubs,
      },
    });

  const findFormActions = () => wrapper.findComponent(ValueStreamFormContentActions);
  const findExtendedFormFields = () => wrapper.findByTestId('extended-form-fields');
  const findDefaultStages = () => findExtendedFormFields().findAllComponents(DefaultStageFields);
  const findCustomStages = () => findExtendedFormFields().findAllComponents(CustomStageFields);
  const findLastCustomStage = () => findCustomStages().wrappers.at(-1);

  const findPresetSelector = () => wrapper.findByTestId('vsa-preset-selector');
  const findRestoreButton = () => wrapper.findByTestId('vsa-reset-button');
  const findRestoreStageButton = (index) => wrapper.findByTestId(`stage-action-restore-${index}`);
  const findHiddenStages = () => wrapper.findAllByTestId('vsa-hidden-stage').wrappers;
  const findCustomStageEventField = (index = 0) =>
    wrapper.findAllComponents(CustomStageEventField).at(index);
  const findFieldErrors = (testId) => wrapper.findByTestId(testId).attributes('invalid-feedback');
  const findNameInput = () =>
    wrapper.findByTestId('create-value-stream-name').findComponent(GlFormInput);
  const findSubmitErrorAlert = () => wrapper.findComponent(GlAlert);

  const fillStageNameAtIndex = (name, index) =>
    findCustomStages().at(index).findComponent(GlFormInput).vm.$emit('input', name);

  const clickSubmit = () => findFormActions().vm.$emit('clickPrimaryAction');
  const clickAddStage = async () => {
    findFormActions().vm.$emit('clickAddStageAction');
    await nextTick();
  };
  const clickRestoreStageAtIndex = (index) => findRestoreStageButton(index).vm.$emit('click');
  const expectFieldError = (testId, error = '') => expect(findFieldErrors(testId)).toBe(error);
  const expectCustomFieldError = (index, attr, error = '') =>
    expect(findCustomStageEventField(index).attributes(attr)).toBe(error);
  const expectStageTransitionKeys = (stages) =>
    stages.forEach((stage) => expect(stage.transitionKey).toContain('stage-'));

  describe('default state', () => {
    beforeEach(() => {
      wrapper = createComponent({ state: { defaultGroupLabels: null } });
    });

    it('has the form header', () => {
      expect(findFormActions().props()).toMatchObject({
        isLoading: false,
        isEditing: false,
        valueStreamPath,
      });
    });

    it('has the extended fields', () => {
      expect(findExtendedFormFields().exists()).toBe(true);
    });

    describe('Preset selector', () => {
      it('has the preset button', () => {
        expect(findPresetSelector().exists()).toBe(true);
      });

      it('will toggle between the blank and default templates', async () => {
        expect(findDefaultStages()).toHaveLength(defaultStageConfig.length);
        expect(findCustomStages()).toHaveLength(0);

        await findPresetSelector().vm.$emit('input', PRESET_OPTIONS_BLANK);

        expect(findDefaultStages()).toHaveLength(0);
        expect(findCustomStages()).toHaveLength(1);

        await findPresetSelector().vm.$emit('input', PRESET_OPTIONS_DEFAULT);

        expect(findDefaultStages()).toHaveLength(defaultStageConfig.length);
        expect(findCustomStages()).toHaveLength(0);
      });

      it('does not clear name when toggling templates', async () => {
        await findNameInput().vm.$emit('input', initialData.name);

        expect(findNameInput().attributes('value')).toBe(initialData.name);

        await findPresetSelector().vm.$emit('input', PRESET_OPTIONS_BLANK);

        expect(findNameInput().attributes('value')).toBe(initialData.name);

        await findPresetSelector().vm.$emit('input', PRESET_OPTIONS_DEFAULT);

        expect(findNameInput().attributes('value')).toBe(initialData.name);
      });

      it('each stage has a transition key when toggling', async () => {
        await findPresetSelector().vm.$emit('input', PRESET_OPTIONS_BLANK);

        expectStageTransitionKeys(wrapper.vm.stages);

        await findPresetSelector().vm.$emit('input', PRESET_OPTIONS_DEFAULT);

        expectStageTransitionKeys(wrapper.vm.stages);
      });

      it('does not display any hidden stages', () => {
        expect(findHiddenStages()).toHaveLength(0);
      });
    });

    describe('Add stage button', () => {
      beforeEach(() => {
        wrapper = createComponent({
          stubs: {
            CustomStageFields,
          },
        });
      });

      it('adds a blank custom stage when clicked', async () => {
        expect(findDefaultStages()).toHaveLength(defaultStageConfig.length);
        expect(findCustomStages()).toHaveLength(0);

        await clickAddStage();

        expect(findDefaultStages()).toHaveLength(defaultStageConfig.length);
        expect(findCustomStages()).toHaveLength(1);
      });

      it('each stage has a transition key', () => {
        expectStageTransitionKeys(wrapper.vm.stages);
      });

      it('scrolls to the last stage after adding', async () => {
        await clickAddStage();

        expect(findLastCustomStage().element.scrollIntoView).toHaveBeenCalledWith({
          behavior: 'smooth',
        });
      });
    });

    describe('field validation', () => {
      beforeEach(() => {
        wrapper = createComponent({
          stubs: {
            CustomStageFields,
          },
        });
      });

      it('validates existing fields when clicked', async () => {
        const fieldTestId = 'create-value-stream-name';
        expect(findFieldErrors(fieldTestId)).toBeUndefined();

        await clickAddStage();

        expectFieldError(fieldTestId, 'Name is required');
      });

      it('does not allow duplicate stage names', async () => {
        const [firstDefaultStage] = defaultStageConfig;
        await findNameInput().vm.$emit('input', streamName);

        await clickAddStage();
        await fillStageNameAtIndex(firstDefaultStage.name, 0);

        // Trigger the field validation
        await clickAddStage();

        expectFieldError('custom-stage-name-3', 'Stage name already exists');
      });
    });

    describe('initial form stage errors', () => {
      const commonExtendedData = {
        props: {
          initialFormErrors: initialFormStageErrors,
        },
      };

      it('renders errors for a default stage field', () => {
        wrapper = createComponent({
          ...commonExtendedData,
          stubs: {
            DefaultStageFields,
          },
        });

        expectFieldError('default-stage-name-0', initialFormStageErrors.stages[0].name[0]);
      });

      it('renders errors for a custom stage field', () => {
        wrapper = createComponent({
          props: {
            ...commonExtendedData.props,
            initialPreset: PRESET_OPTIONS_BLANK,
          },
          stubs: {
            CustomStageFields,
          },
        });

        expectFieldError('custom-stage-name-0', initialFormStageErrors.stages[0].name[0]);
        expectCustomFieldError(
          0,
          'identifiererror',
          initialFormStageErrors.stages[0].startEventIdentifier[0],
        );
      });
    });

    describe('initial form name errors', () => {
      beforeEach(() => {
        wrapper = createComponent({
          props: {
            initialFormErrors: initialFormNameErrors,
          },
        });
      });

      it('renders errors for the name field', () => {
        expectFieldError('create-value-stream-name', initialFormNameErrors.name[0]);
      });
    });

    describe('with valid fields', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      afterEach(() => {
        unmockTracking();
      });

      describe('form submitting', () => {
        beforeEach(() => {
          wrapper = createComponent({
            state: {
              isCreatingValueStream: true,
            },
          });
        });

        it("enables form header's loading state", () => {
          expect(findFormActions().props('isLoading')).toBe(true);
        });
      });

      describe('form submitted successfully', () => {
        beforeEach(async () => {
          wrapper = createComponent();

          await findNameInput().vm.$emit('input', streamName);
          clickSubmit();
        });

        it('calls the "createValueStream" event when submitted', () => {
          expect(createValueStreamMock).toHaveBeenCalledWith(expect.any(Object), {
            name: streamName,
            stages: [
              {
                custom: false,
                name: 'issue',
              },
              {
                custom: false,
                name: 'plan',
              },
              {
                custom: false,
                name: 'code',
              },
            ],
          });
        });

        it('does not display a toast message', () => {
          expect(mockToastShow).not.toHaveBeenCalled();
        });

        it('sends tracking information', () => {
          expect(trackingSpy).toHaveBeenCalledWith(undefined, 'submit_form', {
            label: 'create_value_stream',
          });
        });

        it('form header should be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(true);
        });

        it('redirects to the new value stream page', () => {
          expect(visitUrlWithAlerts).toHaveBeenCalledWith(valueStreamPath, [
            {
              id: 'vsa-settings-form-submission-success',
              message: `'${streamName}' Value Stream has been successfully created.`,
              variant: 'success',
            },
          ]);
        });
      });

      describe('form submission fails', () => {
        beforeEach(async () => {
          wrapper = createComponent({
            props: {
              initialFormErrors: formSubmissionErrors,
            },
            stubs: {
              CustomStageFields,
            },
          });

          await findNameInput().vm.$emit('input', streamName);
          clickSubmit();
        });

        it('calls the createValueStream action', () => {
          expect(createValueStreamMock).toHaveBeenCalled();
        });

        it('does not clear the name field', () => {
          expect(findNameInput().attributes('value')).toBe(streamName);
        });

        it('does not display a toast message', () => {
          expect(mockToastShow).not.toHaveBeenCalled();
        });

        it('does not redirect to the new value stream page', () => {
          expect(visitUrlWithAlerts).not.toHaveBeenCalled();
        });

        it('form header should not be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(false);
        });

        it('renders errors for the name field', () => {
          expectFieldError('create-value-stream-name', formSubmissionErrors.name[0]);
        });

        it('renders a dismissible generic alert error', async () => {
          expect(findSubmitErrorAlert().exists()).toBe(true);
          await findSubmitErrorAlert().vm.$emit('dismiss');
          expect(findSubmitErrorAlert().exists()).toBe(false);
        });
      });
    });
  });

  describe('isEditing=true', () => {
    const stageCount = initialData.stages.length;
    beforeEach(() => {
      wrapper = createComponent({
        props: {
          initialPreset,
          initialData,
          isEditing: true,
        },
      });
    });

    it('does not have the preset button', () => {
      expect(findPresetSelector().exists()).toBe(false);
    });

    it("enables form header's editing state", () => {
      expect(findFormActions().props('isEditing')).toBe(true);
    });

    it('does not display any hidden stages', () => {
      expect(findHiddenStages()).toHaveLength(0);
    });

    it('each stage has a transition key', () => {
      expectStageTransitionKeys(wrapper.vm.stages);
    });

    describe('restore defaults button', () => {
      it('restores the original name', async () => {
        const newName = 'name';

        await findNameInput().vm.$emit('input', newName);

        expect(findNameInput().attributes('value')).toBe(newName);

        await findRestoreButton().vm.$emit('click');

        expect(findNameInput().attributes('value')).toBe(initialData.name);
      });

      it('will clear the form fields', async () => {
        expect(findCustomStages()).toHaveLength(stageCount);

        await clickAddStage();

        expect(findCustomStages()).toHaveLength(stageCount + 1);

        await findRestoreButton().vm.$emit('click');

        expect(findCustomStages()).toHaveLength(stageCount);
      });
    });

    describe('with hidden stages', () => {
      const hiddenStages = defaultStageConfig.map((s) => ({ ...s, hidden: true }));

      beforeEach(() => {
        wrapper = createComponent({
          props: {
            initialPreset,
            initialData: { ...initialData, stages: [...initialData.stages, ...hiddenStages] },
            isEditing: true,
          },
        });
      });

      it('displays hidden each stage', () => {
        expect(findHiddenStages()).toHaveLength(hiddenStages.length);

        findHiddenStages().forEach((s) => {
          expect(s.text()).toContain('Restore stage');
        });
      });

      it('when `Restore stage` is clicked, the stage is restored', async () => {
        expect(findHiddenStages()).toHaveLength(hiddenStages.length);
        expect(findDefaultStages()).toHaveLength(0);
        expect(findCustomStages()).toHaveLength(stageCount);

        await clickRestoreStageAtIndex(1);

        expect(findHiddenStages()).toHaveLength(hiddenStages.length - 1);
        expect(findDefaultStages()).toHaveLength(1);
        expect(findCustomStages()).toHaveLength(stageCount);
      });

      it('when a stage is restored it has a transition key', async () => {
        await clickRestoreStageAtIndex(1);

        expect(wrapper.vm.stages[stageCount].transitionKey).toContain(
          `stage-${hiddenStages[1].name}-`,
        );
      });
    });

    describe('Add stage button', () => {
      beforeEach(() => {
        wrapper = createComponent({
          props: {
            initialPreset,
            initialData,
            isEditing: true,
          },
          stubs: {
            CustomStageFields,
          },
        });
      });

      it('adds a blank custom stage when clicked', async () => {
        expect(findCustomStages()).toHaveLength(stageCount);

        await clickAddStage();

        expect(findCustomStages()).toHaveLength(stageCount + 1);
      });

      it('validates existing fields when clicked', async () => {
        const fieldTestId = 'create-value-stream-name';
        expect(findFieldErrors(fieldTestId)).toBeUndefined();

        await findNameInput().vm.$emit('input', '');
        await clickAddStage();

        expectFieldError(fieldTestId, 'Name is required');
      });
    });

    describe('with valid fields', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      afterEach(() => {
        unmockTracking();
      });

      describe('form submitting', () => {
        beforeEach(() => {
          wrapper = createComponent({
            props: {
              initialPreset,
              initialData,
              isEditing: true,
            },
            state: {
              isEditingValueStream: true,
            },
          });
        });

        it("enables form header's loading state", () => {
          expect(findFormActions().props('isLoading')).toBe(true);
        });
      });

      describe('form submitted successfully', () => {
        beforeEach(() => {
          wrapper = createComponent({
            props: {
              initialPreset,
              initialData,
              isEditing: true,
            },
          });

          clickSubmit();
        });

        it('calls the "updateValueStreamMock" event when submitted', () => {
          expect(updateValueStreamMock).toHaveBeenCalledWith(expect.any(Object), {
            ...initialData,
            stages: initialData.stages.map((stage) =>
              convertObjectPropsToSnakeCase(stage, { deep: true }),
            ),
          });
        });

        it('form header should be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(true);
        });

        it('redirects to the updated value stream page', () => {
          expect(visitUrlWithAlerts).toHaveBeenCalledWith(valueStreamPath, [
            {
              id: 'vsa-settings-form-submission-success',
              message: `'${initialData.name}' Value Stream has been successfully saved.`,
              variant: 'success',
            },
          ]);
        });

        it('sends tracking information', () => {
          expect(trackingSpy).toHaveBeenCalledWith(undefined, 'submit_form', {
            label: 'edit_value_stream',
          });
        });
      });

      describe('form submission fails', () => {
        beforeEach(() => {
          wrapper = createComponent({
            props: {
              initialFormErrors: formSubmissionErrors,
              initialData,
              initialPreset,
              isEditing: true,
            },
            stubs: {
              CustomStageFields,
            },
          });

          clickSubmit();
        });

        it('calls the updateValueStreamMock action', () => {
          expect(updateValueStreamMock).toHaveBeenCalled();
        });

        it('does not clear the name field', () => {
          const { name } = initialData;

          expect(findNameInput().attributes('value')).toBe(name);
        });

        it('does not display a toast message', () => {
          expect(mockToastShow).not.toHaveBeenCalled();
        });

        it('does not redirect to the value stream page', () => {
          expect(visitUrlWithAlerts).not.toHaveBeenCalled();
        });

        it('form header should not be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(false);
        });

        it('renders errors for the name field', () => {
          expectFieldError('create-value-stream-name', formSubmissionErrors.name[0]);
        });

        it('renders errors for a custom stage field', () => {
          expectFieldError('custom-stage-name-0', formSubmissionErrors.stages[0].name[0]);
        });

        it('renders a dismissible generic alert error', async () => {
          expect(findSubmitErrorAlert().exists()).toBe(true);
          await findSubmitErrorAlert().vm.$emit('dismiss');
          expect(findSubmitErrorAlert().exists()).toBe(false);
        });
      });
    });
  });
});
