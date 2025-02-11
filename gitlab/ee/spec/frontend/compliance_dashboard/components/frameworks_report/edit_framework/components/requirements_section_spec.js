import { GlTable, GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import RequirementsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirements_section.vue';
import RequirementModal from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirement_modal.vue';
import EditSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/edit_section.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { mockRequirements, mockRequirementControls } from 'ee_jest/compliance_dashboard/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import controlsQuery from 'ee/compliance_dashboard/graphql/compliance_requirement_controls.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import {
  requirementEvents,
  emptyRequirement,
} from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/constants';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('Requirements section', () => {
  let wrapper;

  const error = new Error('GraphQL error');

  let controlsQueryHandler;

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const findNewRequirementButton = () => wrapper.findByTestId('add-requirement-button');
  const findRequirementModal = () => wrapper.findComponent(RequirementModal);
  const findDeleteAction = () => wrapper.findByTestId('delete-action');
  const findEditAction = () => wrapper.findByTestId('edit-action');

  const createComponent = async ({
    controlsQueryHandlerMockResponse = controlsQueryHandler,
    isNewFramework = true,
  } = {}) => {
    const mockApollo = createMockApollo([[controlsQuery, controlsQueryHandlerMockResponse]]);

    wrapper = mountExtended(RequirementsSection, {
      propsData: {
        requirements: mockRequirements,
        isNewFramework,
      },
      apolloProvider: mockApollo,
      stubs: { GlDisclosureDropdown, GlDisclosureDropdownItem },
    });

    await waitForPromises();
  };

  describe('Rendering', () => {
    controlsQueryHandler = jest.fn().mockResolvedValue({
      data: {
        complianceRequirementControls: {
          controlExpressions: mockRequirementControls,
        },
      },
    });
    beforeEach(async () => {
      await createComponent();
    });

    it('Has title', () => {
      const title = wrapper.findByText('Requirements');
      expect(title.exists()).toBe(true);
    });

    it('correctly displays description', () => {
      const description = wrapper.findByText(
        'Configure requirements set forth by laws, regulations, and industry standards.',
      );
      expect(description.exists()).toBe(true);
    });

    it('passes correct items prop to a table', () => {
      const { items } = findTable().vm.$attrs;
      expect(items).toHaveLength(mockRequirements.length);
    });

    it('renders section as initially expanded if is-new-framework prop is true', () => {
      expect(wrapper.findComponent(EditSection).props('initiallyExpanded')).toBe(true);
    });

    it('renders section as collapsed if is-new-framework prop is false', async () => {
      await createComponent({ isNewFramework: false });
      expect(wrapper.findComponent(EditSection).props('initiallyExpanded')).toBe(false);
    });

    it.each`
      idx  | expectedRequirement    | expectedControls
      ${0} | ${mockRequirements[0]} | ${[]}
      ${1} | ${mockRequirements[1]} | ${[mockRequirementControls[1], mockRequirementControls[0]]}
    `(
      'passes the correct items prop to the table at index $idx',
      async ({ idx, expectedRequirement, expectedControls }) => {
        await createComponent();
        const { items } = findTable().vm.$attrs;
        const item = items[idx];
        expect(item.name).toBe(expectedRequirement.name);
        expect(item.description).toBe(expectedRequirement.description);
        expect(item.controls).toMatchObject(expectedControls);
      },
    );

    it.each`
      idx  | name        | description                  | controls
      ${0} | ${'SOC2'}   | ${'Controls for SOC2'}       | ${[]}
      ${1} | ${'GitLab'} | ${'Controls used by GitLab'} | ${['Minimum approvals required', 'SAST Running']}
    `('has the correct data for row $idx', ({ idx, name, description, controls }) => {
      const frameworkRequirements = findTableRowData(idx);

      expect(frameworkRequirements.at(0).text()).toBe(name);
      expect(frameworkRequirements.at(1).text()).toBe(description);
      expect(
        frameworkRequirements
          .at(2)
          .findAll('li')
          .wrappers.map((w) => w.text()),
      ).toEqual(controls);
    });

    describe('Create requirement button', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders create requirement', () => {
        expect(findNewRequirementButton().text()).toBe('New requirement');
      });
    });
  });

  describe('Fetching data', () => {
    beforeEach(() => {
      controlsQueryHandler = jest.fn().mockResolvedValue({
        data: {
          complianceRequirementControls: {
            controlExpressions: mockRequirementControls,
          },
        },
      });
      createComponent();
    });

    it('calls the complianceRequirementControls query', () => {
      expect(controlsQueryHandler).toHaveBeenCalled();
    });

    it('updates data', async () => {
      await findNewRequirementButton().trigger('click');
      expect(findRequirementModal().props('requirementControls')).toMatchObject(
        mockRequirementControls,
      );
    });
  });

  describe('Error handling', () => {
    beforeEach(async () => {
      controlsQueryHandler = jest.fn().mockRejectedValue(error);
      await createComponent({ controlsQueryHandler });
    });

    it('calls createAlert with the correct message on query error', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error fetching compliance requirements controls data. Please refresh the page.',
        captureException: true,
        error,
      });
    });
  });

  describe('Creating requirement', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('passes corect props to requirement modal', async () => {
      await findNewRequirementButton().trigger('click');
      expect(findRequirementModal().props('requirement')).toMatchObject({
        ...emptyRequirement,
        index: null,
      });
    });

    it('emits a create event with the correct data when the requirement is created', async () => {
      await findNewRequirementButton().trigger('click');

      const newRequirement = {
        ...mockRequirements[0],
        name: 'New Requirement',
      };

      await findRequirementModal().vm.$emit(requirementEvents.create, {
        requirement: newRequirement,
        index: null,
      });
      expect(wrapper.emitted('create')).toEqual([[{ requirement: newRequirement, index: null }]]);
      expect(findRequirementModal().exists()).toBe(false);
    });
  });

  describe('Delete requirement', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('emits a delete event with the correct index when delete action is clicked', async () => {
      await findDeleteAction().vm.$emit('action');
      expect(wrapper.emitted(requirementEvents.delete)).toStrictEqual([[0]]);
    });
  });

  describe('Update requirement', () => {
    const index = 0;
    beforeEach(async () => {
      await createComponent();
    });

    it('passes corect props to requirement modal', async () => {
      await findEditAction().vm.$emit('action');
      expect(findRequirementModal().props('requirement')).toMatchObject({
        ...mockRequirements[index],
        index,
      });
    });

    it('emits an update event with the correct data when the requirement is updated', async () => {
      await findEditAction().vm.$emit('action');

      const updatedRequirement = {
        ...mockRequirements[index],
        name: 'Updated SOC2 Requirement',
      };

      await findRequirementModal().vm.$emit(requirementEvents.update, {
        requirement: updatedRequirement,
        index,
      });
      expect(wrapper.emitted('update')).toEqual([[{ requirement: updatedRequirement, index }]]);
      expect(findRequirementModal().exists()).toBe(false);
    });
  });
});
