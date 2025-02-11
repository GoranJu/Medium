import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CustomFieldForm from 'ee/groups/settings/work_items/custom_field_form.vue';
import createCustomFieldMutation from 'ee/groups/settings/work_items/create_custom_field.mutation.graphql';
import updateCustomFieldMutation from 'ee/groups/settings/work_items/update_custom_field.mutation.graphql';
import groupCustomFieldQuery from 'ee/groups/settings/work_items/group_custom_field.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('CustomFieldForm', () => {
  let wrapper;

  const findToggleModalButton = () => wrapper.findByTestId('toggle-modal');
  const findEditButton = () => wrapper.findByTestId('toggle-edit-modal');
  const findModal = () => wrapper.findComponent(GlModal);
  const findFieldTypeSelect = () => wrapper.find('#field-type');
  const findFieldNameFormGroup = () => wrapper.find('[label-for="field-name"]');
  const findFieldNameInput = () => wrapper.find('#field-name');

  const findCustomFieldOptionsFormGroup = () =>
    wrapper.find('[data-testid="custom-field-options"]');
  const findAddSelectOptionButton = () => wrapper.findByTestId('add-select-option');
  const findAddSelectInputAt = (i) => wrapper.findByTestId(`select-options-${i}`);

  const findRemoveSelectButtonAt = (i) => wrapper.findByTestId(`remove-select-option-${i}`);

  const findSaveCustomFieldButton = () => wrapper.findByTestId('save-custom-field');
  const findUpdateCustomFieldButton = () => wrapper.findByTestId('update-custom-field');

  const mockCreateFieldResponse = {
    data: {
      customFieldCreate: {
        customField: {
          id: 'gid://gitlab/Issuables::CustomField/13',
        },
        errors: [],
      },
    },
  };

  const mockUpdateFieldResponse = {
    data: {
      customFieldUpdate: {
        customField: {
          id: 'gid://gitlab/Issuables::CustomField/13',
          name: 'Updated Field',
        },
        errors: [],
      },
    },
  };

  const mockExistingField = {
    id: 'gid://gitlab/Issuables::CustomField/13',
    name: 'Existing Field',
    fieldType: 'SINGLE_SELECT',
    active: true,
    updatedAt: '2023-01-01T00:00:00Z',
    createdAt: '2023-01-01T00:00:00Z',
    selectOptions: [
      { id: '1', value: 'Option 1' },
      { id: '2', value: 'Option 2' },
    ],
    workItemTypes: [{ id: '1', name: 'Issue' }],
  };

  const fullPath = 'group/subgroup';

  const createComponent = ({
    props = {},
    createFieldResponse = {},
    updateFieldResponse = {},
    existingFieldResponse = {},
    createFieldHandler = jest.fn().mockResolvedValue(createFieldResponse),
    updateFieldHandler = jest.fn().mockResolvedValue(updateFieldResponse),
    existingFieldHandler = jest.fn().mockResolvedValue(existingFieldResponse),
  } = {}) => {
    wrapper = shallowMountExtended(CustomFieldForm, {
      propsData: {
        ...props,
      },
      provide: {
        fullPath,
      },
      apolloProvider: createMockApollo([
        [createCustomFieldMutation, createFieldHandler],
        [updateCustomFieldMutation, updateFieldHandler],
        [groupCustomFieldQuery, existingFieldHandler],
      ]),
      stubs: {
        GlModal,
      },
    });
  };

  describe('initial rendering', () => {
    it('renders create field button when not editing', () => {
      createComponent();
      expect(findToggleModalButton().text()).toBe('Create field');
    });

    it('renders edit button when editing', () => {
      createComponent({ props: { customFieldId: '13' } });
      expect(findEditButton().exists()).toBe(true);
    });

    it('modal is hidden by default', () => {
      createComponent();
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('modal visibility', () => {
    it('shows modal when create button is clicked', async () => {
      createComponent();
      await findToggleModalButton().vm.$emit('click');
      expect(findModal().props('visible')).toBe(true);
    });

    it('shows modal when edit button is clicked', async () => {
      createComponent({ props: { customFieldId: '13' } });
      await findEditButton().vm.$emit('click');
      expect(findModal().props('visible')).toBe(true);
    });

    it('hides modal when hide event is emitted', async () => {
      createComponent();
      await findToggleModalButton().vm.$emit('click');
      await findModal().vm.$emit('hide');
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('form behavior', () => {
    beforeEach(() => {
      createComponent();
      findToggleModalButton().vm.$emit('click');
    });

    it.each(['SINGLE_SELECT', 'MULTI_SELECT'])(
      `shows select options section when field type is %s`,
      async (type) => {
        await findFieldTypeSelect().vm.$emit('input', type);
        await nextTick();

        expect(findAddSelectOptionButton().exists()).toBe(true);
        expect(findAddSelectInputAt(0).exists()).toBe(true);
      },
    );

    it.each(['NUMBER', 'TEXT'])(
      `hides select options section when field type is %s`,
      async (type) => {
        await findFieldTypeSelect().vm.$emit('input', type);
        await nextTick();

        expect(findAddSelectOptionButton().exists()).toBe(false);
        expect(findAddSelectInputAt(0).exists()).toBe(false);
      },
    );

    it('adds select option when add button is clicked', async () => {
      await findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');
      await nextTick();

      expect(findAddSelectOptionButton().exists()).toBe(true);
      expect(findAddSelectInputAt(1).exists()).toBe(false);

      findAddSelectOptionButton().vm.$emit('click');
      await nextTick();

      expect(findAddSelectInputAt(1).exists()).toBe(true);
    });

    it('remove button removes select option', async () => {
      await findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');
      await nextTick();

      findRemoveSelectButtonAt(0).vm.$emit('click');
      await nextTick();

      expect(findAddSelectInputAt(0).exists()).toBe(false);
    });
  });

  describe('saveCustomField', () => {
    it('calls create mutation with correct variables when creating', async () => {
      const createFieldHandler = jest.fn().mockResolvedValue(mockCreateFieldResponse);
      createComponent({ createFieldHandler });

      await findToggleModalButton().vm.$emit('click');

      await findFieldTypeSelect().vm.$emit('input', 'TEXT');
      await findFieldNameInput().vm.$emit('input', 'Test Field');

      await nextTick();

      findSaveCustomFieldButton().vm.$emit('click');

      await waitForPromises();

      expect(Sentry.captureException).not.toHaveBeenCalled();

      expect(createFieldHandler).toHaveBeenCalledWith({
        groupPath: fullPath,
        name: 'Test Field',
        fieldType: 'TEXT',
        selectOptions: undefined,
      });
    });

    it('calls update mutation with correct variables when editing', async () => {
      const updateFieldHandler = jest.fn().mockResolvedValue(mockUpdateFieldResponse);
      const existingFieldHandler = jest
        .fn()
        .mockResolvedValue({ data: { group: { id: '1', customField: mockExistingField } } });
      createComponent({
        props: { customFieldId: 'gid://gitlab/Issuables::CustomField/13' },
        updateFieldHandler,
        existingFieldHandler,
      });

      await findEditButton().vm.$emit('click');
      await waitForPromises();

      await findFieldNameInput().vm.$emit('input', 'Updated Field');

      await nextTick();

      findUpdateCustomFieldButton().vm.$emit('click');

      await waitForPromises();

      expect(Sentry.captureException).not.toHaveBeenCalled();

      expect(updateFieldHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/Issuables::CustomField/13',
        name: 'Updated Field',
        selectOptions: [
          { id: '1', value: 'Option 1' },
          { id: '2', value: 'Option 2' },
        ],
      });
    });

    it('shows validation error if field name is empty', async () => {
      createComponent({ createFieldResponse: mockCreateFieldResponse });
      await findToggleModalButton().vm.$emit('click');

      await nextTick();

      expect(findFieldNameFormGroup().attributes('invalid-feedback')).toBe('Name is required.');
    });

    it('shows validation error if no select options added', async () => {
      createComponent({ createFieldResponse: mockCreateFieldResponse });
      await findToggleModalButton().vm.$emit('click');

      await findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');

      await nextTick();

      expect(findCustomFieldOptionsFormGroup().attributes('invalid-feedback')).toBe(
        'At least one option is required.',
      );
    });

    it('handles mutation errors', async () => {
      const errorMessage = 'Error creating custom field';
      const errorResponse = {
        data: {
          customFieldCreate: {
            customField: null,
            errors: [errorMessage],
          },
        },
      };
      createComponent({ createFieldResponse: errorResponse });
      await findToggleModalButton().vm.$emit('click');

      await findFieldTypeSelect().vm.$emit('input', 'TEXT');
      await findFieldNameInput().vm.$emit('input', 'Test Field');

      findSaveCustomFieldButton().vm.$emit('click');

      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });

  describe('edit mode', () => {
    it('loads existing field data when editing', async () => {
      const existingFieldHandler = jest
        .fn()
        .mockResolvedValue({ data: { group: { id: '1', customField: mockExistingField } } });
      createComponent({
        props: { customFieldId: 'gid://gitlab/Issuables::CustomField/13' },
        existingFieldHandler,
      });

      await findEditButton().vm.$emit('click');
      await waitForPromises();

      expect(Sentry.captureException).not.toHaveBeenCalled();

      expect(findFieldNameInput().attributes().value).toBe('Existing Field');
      expect(findFieldTypeSelect().exists()).toBe(false);
      expect(findAddSelectInputAt(0).attributes().value).toBe('Option 1');
      expect(findAddSelectInputAt(1).attributes().value).toBe('Option 2');
    });

    it('hides field type select when editing', async () => {
      const existingFieldHandler = jest
        .fn()
        .mockResolvedValue({ data: { group: { id: '1', customField: mockExistingField } } });
      createComponent({
        props: { customFieldId: 'gid://gitlab/Issuables::CustomField/13' },
        existingFieldHandler,
      });

      await findEditButton().vm.$emit('click');
      await waitForPromises();

      expect(findFieldTypeSelect().exists()).toBe(false);
    });
  });
});
