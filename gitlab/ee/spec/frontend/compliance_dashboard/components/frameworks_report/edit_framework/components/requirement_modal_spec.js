import {
  GlModal,
  GlFormInput,
  GlFormTextarea,
  GlBadge,
  GlTooltip,
  GlCollapsibleListbox,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RequirementModal from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirement_modal.vue';
import {
  emptyRequirement,
  requirementEvents,
} from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { mockRequirementControls, mockRequirements } from 'ee_jest/compliance_dashboard/mock_data';

describe('RequirementModal', () => {
  let wrapper;

  const defaultProps = {
    requirement: { ...emptyRequirement, index: null },
    requirementControls: mockRequirementControls,
    isNewFramework: true,
  };

  const mockEvent = {
    preventDefault: jest.fn(),
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findNameInput = () => wrapper.findComponent(GlFormInput);
  const findNameInputGroup = () => wrapper.findByTestId('name-input-group');
  const findDescriptionTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findDescriptionInputGroup = () => wrapper.findByTestId('description-input-group');
  const submitModalForm = () => findModal().vm.$emit('primary', mockEvent);
  const findAddControlButton = () => wrapper.findByTestId('add-control-button');
  const findControlSelectors = () => wrapper.findAllComponents(GlCollapsibleListbox);
  const findControlAtIndex = (index) => wrapper.findByTestId(`control-select-${index}`);
  const findControlsBadge = () => wrapper.findComponent(GlBadge);
  const findTooltip = () => wrapper.findComponent(GlTooltip);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(RequirementModal, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const addControl = async (controlId = null, index = 0) => {
    await findAddControlButton().vm.$emit('click');
    await nextTick();
    if (controlId !== null) {
      const controlSelector = findControlAtIndex(index);
      if (controlSelector.exists()) {
        await controlSelector.vm.$emit('select', controlId);
        await nextTick();
      }
    }
  };

  const fillForm = async (name, description, controls = []) => {
    if (name !== undefined) {
      await findNameInput().vm.$emit('input', name);
    }
    if (description !== undefined) {
      await findDescriptionTextarea().vm.$emit('input', description);
    }
    for (const [index, controlId] of controls.entries()) {
      // eslint-disable-next-line no-await-in-loop
      await addControl(controlId, index);
    }
  };

  describe('Rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('renders the name input field', () => {
      expect(findNameInput().exists()).toBe(true);
    });

    it('renders the description textarea', () => {
      expect(findDescriptionTextarea().exists()).toBe(true);
    });

    it('renders the correct title for a new requirement', () => {
      expect(findModal().attributes('title')).toBe('Create new requirement');
    });

    it('renders the controls selection UI', () => {
      expect(findAddControlButton().exists()).toBe(true);
    });

    it('shows the initial controls count as 0', () => {
      expect(findControlsBadge().text()).toBe('0');
    });
  });

  describe('Interaction', () => {
    beforeEach(() => {
      createComponent();
    });

    it('allows adding a control', async () => {
      expect(findControlSelectors()).toHaveLength(1);
      await addControl();
      expect(findControlSelectors()).toHaveLength(2);
    });

    it('updates the controls count when controls are selected', async () => {
      await addControl('scanner_sast_running');
      expect(findControlsBadge().text()).toBe('1');
    });

    it('prevents adding more than 5 controls', async () => {
      for (let i = 0; i < 5; i += 1) {
        // eslint-disable-next-line no-await-in-loop
        await addControl();
      }
      expect(findControlSelectors()).toHaveLength(5);
      expect(findAddControlButton().attributes('disabled')).toBeDefined();
      expect(findTooltip().exists()).toBe(true);
      expect(findTooltip().attributes('title')).toBe('You can create a maximum of 5 controls');
    });

    it('emits create event with requirement data including selected controls', async () => {
      const name = 'Test Name';
      const description = 'Test Description';
      await fillForm(name, description, ['scanner_sast_running', 'default_branch_protected']);
      submitModalForm();
      await waitForPromises();
      expect(wrapper.emitted(requirementEvents.create)).toMatchObject([
        [
          {
            index: null,
            requirement: {
              description,
              name,
              controlExpression:
                '{"operator":"AND","conditions":[{"id":"scanner_sast_running","field":"scanner_sast_running","operator":"=","value":true},{"id":"default_branch_protected","field":"default_branch_protected","operator":"=","value":true}]}',
            },
          },
        ],
      ]);
    });

    it('filters out selected controls from already selected selectors', async () => {
      await addControl('scanner_sast_running');
      await addControl();
      const secondControlItems = findControlAtIndex(1).props('items');
      expect(secondControlItems).not.toEqual(
        expect.arrayContaining([expect.objectContaining({ value: 'scanner_sast_running' })]),
      );
    });
  });

  it('emits update event with correct data including controls when editing an existing requirement', async () => {
    createComponent({
      requirement: { ...mockRequirements[0], index: 0 },
      isNewFramework: false,
      requirementControls: mockRequirementControls,
    });
    await fillForm('Updated Name', 'Updated Description', [
      'scanner_sast_running',
      'default_branch_protected',
    ]);
    submitModalForm();
    await waitForPromises();
    expect(wrapper.emitted(requirementEvents.update)).toEqual([
      [
        {
          requirement: {
            name: 'Updated Name',
            description: 'Updated Description',
            id: mockRequirements[0].id,
            __typename: 'ComplianceManagement::Requirement',
            controlExpression:
              '{"operator":"AND","conditions":[{"id":"scanner_sast_running","field":"scanner_sast_running","operator":"=","value":true},{"id":"default_branch_protected","field":"default_branch_protected","operator":"=","value":true}]}',
          },
          index: 0,
        },
      ],
    ]);
  });

  describe('Validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('validates that name is required', async () => {
      submitModalForm();
      await waitForPromises();
      expect(findNameInputGroup().attributes('state')).toBeUndefined();
    });

    it('validates that description is required', async () => {
      submitModalForm();
      await waitForPromises();
      expect(findDescriptionInputGroup().attributes('state')).toBeUndefined();
    });

    it('validates that the form is valid when fields are filled', async () => {
      const name = 'Test Name';
      const description = 'Test Description';
      await fillForm(name, description);
      submitModalForm();
      await waitForPromises();
      expect(findNameInputGroup().attributes('state')).toBe('true');
      expect(findDescriptionInputGroup().attributes('state')).toBe('true');
    });

    it('emits save event with requirement data', async () => {
      const name = 'Test Name';
      const description = 'Test Description';
      await fillForm(name, description);
      submitModalForm();
      await waitForPromises();
      expect(wrapper.emitted(requirementEvents.create)).toEqual([
        [
          {
            index: null,
            requirement: {
              description,
              name,
              controlExpression: null,
            },
          },
        ],
      ]);
    });
  });
});
