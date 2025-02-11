import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import { GlBadge } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TimeagoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import CustomFieldForm from 'ee/groups/settings/work_items/custom_field_form.vue';
import CustomFieldsTable from 'ee/groups/settings/work_items/custom_fields_list.vue';
import groupCustomFieldsQuery from 'ee/groups/settings/work_items/group_custom_fields.query.graphql';
import customFieldArchiveMutation from 'ee/groups/settings/work_items/custom_field_archive.mutation.graphql';

Vue.use(VueApollo);

describe('CustomFieldsTable', () => {
  let wrapper;
  let apolloProvider;

  const selectField = {
    id: '1',
    name: 'Test Select Field',
    fieldType: 'SELECT',
    active: true,
    workItemTypes: [{ id: '1', name: 'Issue' }],
    selectOptions: [
      {
        id: 'select-1',
        value: 'value 1',
      },
      {
        id: 'select-2',
        value: 'value 2',
      },
    ],
    updatedAt: '2023-01-01T00:00:00Z',
    createdAt: '2023-01-01T00:00:00Z',
  };

  const stringField = {
    id: '1',
    name: 'Test Text Field',
    fieldType: 'STRING',
    active: true,
    workItemTypes: [
      { id: '1', name: 'Issue' },
      { id: '2', name: 'Task' },
    ],
    selectOptions: [],
    updatedAt: '2023-01-01T00:00:00Z',
    createdAt: '2023-01-01T00:00:00Z',
  };

  const createQueryResponse = (fields = [stringField]) => ({
    data: {
      group: {
        id: '123',
        customFields: {
          nodes: fields,
          count: fields.length,
        },
      },
    },
  });

  const findTableItems = () => wrapper.findAll('tbody tr');
  const findArchiveButton = () => wrapper.find('[data-testid="archiveButton"]');
  const findDetailsButton = () => wrapper.find('[data-testid="toggleDetailsButton"');
  const findAlert = () => wrapper.find('[data-testid="alert"]');
  const findActiveFilterButton = () => wrapper.find('[data-testid="activeFilterButton"]');
  const findArchivedFilterButton = () => wrapper.find('[data-testid="archivedFilterButton"]');
  const findTitle = () => wrapper.find('[data-testid="table-title"]');

  const createComponent = ({
    fields = [selectField],
    customFieldsResponse = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '123',
          customFields: {
            nodes: fields,
            count: fields.length,
          },
        },
      },
    }),
    archiveMutationResponse = jest.fn().mockResolvedValue({
      data: {
        customFieldArchive: {
          customField: {
            id: '1',
            name: 'Test Field',
            fieldType: 'STRING',
          },
          errors: [],
        },
      },
    }),
  } = {}) => {
    apolloProvider = createMockApollo([
      [groupCustomFieldsQuery, customFieldsResponse],
      [customFieldArchiveMutation, archiveMutationResponse],
    ]);
    wrapper = mount(CustomFieldsTable, {
      provide: {
        fullPath: 'group/path',
      },
      apolloProvider,
      stubs: { GlIntersperse: true },
    });
  };

  describe('fields loaded', () => {
    beforeEach(() => {
      createComponent();
      return waitForPromises();
    });

    it('displays correct count in badge', () => {
      const badge = wrapper.findComponent(GlBadge);
      expect(badge.text()).toBe('1/50');
    });

    it('renders filter buttons', () => {
      expect(findActiveFilterButton().exists()).toBe(true);
      expect(findArchivedFilterButton().exists()).toBe(true);
    });

    it('sets active filter button as selected by default', () => {
      expect(findActiveFilterButton().props('selected')).toBe(true);
      expect(findArchivedFilterButton().props('selected')).toBe(false);
    });

    it('toggles button selected states when clicked', async () => {
      findArchivedFilterButton().vm.$emit('click');

      await nextTick();

      expect(findActiveFilterButton().props('selected')).toBe(false);
      expect(findArchivedFilterButton().props('selected')).toBe(true);
    });

    it('detailsToggleIcon returns correct icon based on visibility', async () => {
      expect(findDetailsButton().props().icon).toBe('chevron-right');

      findDetailsButton().vm.$emit('click');
      await nextTick();

      expect(findDetailsButton().props().icon).toBe('chevron-down');
    });

    it('humanizes field type', () => {
      expect(wrapper.text()).toContain('Select');
    });

    it('selectOptionsText returns correct text based on options length', () => {
      expect(wrapper.text()).toContain('2 options');
    });

    it('lists work item types', () => {
      // Override default component creation for this test
      createComponent({ fields: [stringField] });
      return waitForPromises().then(() => {
        expect(wrapper.text()).toContain('Issue');
        expect(wrapper.text()).toContain('Task');
      });
    });

    it('toggles details when detail button is clicked', async () => {
      expect(wrapper.text()).not.toContain('Last updated');
      await findDetailsButton().vm.$emit('click');

      expect(wrapper.text()).toContain('Last updated');
    });

    it('renders TimeagoTooltip components with correct timestamps', () => {
      const timeagoComponents = wrapper.findAllComponents(TimeagoTooltip);
      expect(timeagoComponents.exists()).toBe(true);
      expect(timeagoComponents.at(0).props('time')).toBe(selectField.updatedAt);
    });
  });

  it('refetches list after create-custom-field emits created', async () => {
    const customFieldsResponse = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '123',
          customFields: {
            nodes: [],
            count: 0,
          },
        },
      },
    });

    createComponent({
      customFieldsResponse,
    });
    await waitForPromises();

    expect(customFieldsResponse).toHaveBeenCalledTimes(1);

    wrapper.findComponent(CustomFieldForm).vm.$emit('created');

    expect(customFieldsResponse).toHaveBeenCalledTimes(2);
  });

  it('shows dismissable alert when query fails', async () => {
    createComponent({
      customFieldsResponse: jest.fn().mockRejectedValue(new Error('error')),
    });
    await waitForPromises();
    expect(findAlert().exists()).toBe(true);

    findAlert().vm.$emit('dismiss');
    await nextTick();
    expect(findAlert().exists()).toBe(false);
  });

  it('optimistically removes field when archive button is clicked', async () => {
    const fields = [stringField, { ...stringField, id: '2', name: 'Second Field' }];
    const archiveMutationResponse = jest.fn().mockImplementation(() => new Promise(() => {})); // Never resolves

    createComponent({ fields, archiveMutationResponse });
    await waitForPromises();

    expect(findTableItems()).toHaveLength(2);

    findArchiveButton().vm.$emit('click');
    await nextTick();

    expect(findTableItems()).toHaveLength(1);
  });

  it('updates apollo cache after successful archive', async () => {
    const initialResponse = createQueryResponse([stringField]);
    const customFieldsHandler = jest
      .fn()
      .mockResolvedValueOnce(initialResponse)
      .mockResolvedValueOnce({
        data: {
          group: {
            ...initialResponse.data.group,
            customFields: {
              nodes: [],
              count: 0,
            },
          },
        },
      });

    createComponent({ customFieldsHandler });
    await waitForPromises();

    findArchiveButton().vm.$emit('click');
    await waitForPromises();

    const result = await apolloProvider.clients.defaultClient.query({
      query: groupCustomFieldsQuery,
      variables: { fullPath: 'group/path', active: true },
    });

    expect(result.data.group.customFields.nodes).toHaveLength(0);
  });

  it('shows alert on mutation error', async () => {
    const archiveMutationResponse = jest.fn().mockRejectedValue(new Error('Network error'));

    createComponent({
      archiveMutationResponse,
    });
    await waitForPromises();

    expect(findAlert().exists()).toBe(false);

    await findArchiveButton().vm.$emit('click');
    await waitForPromises();

    expect(findAlert().exists()).toBe(true);
    expect(findAlert().text()).toContain(`Failed to archive custom field ${selectField.name}.`);
  });

  it('updates title text when filter changes', async () => {
    createComponent();

    expect(findTitle().text()).toContain('Active custom fields');

    await findArchivedFilterButton().vm.$emit('click');

    expect(findTitle().text()).toContain('Archived custom fields');
  });

  it('updates query variables when switching to archived view', async () => {
    const customFieldsResponse = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '123',
          customFields: {
            nodes: [],
            count: 0,
          },
        },
      },
    });

    createComponent({ customFieldsResponse });
    await waitForPromises();

    // First call should be for active fields
    expect(customFieldsResponse).toHaveBeenCalledWith({
      fullPath: 'group/path',
      active: true,
    });

    await findArchivedFilterButton().vm.$emit('click');
    await waitForPromises();

    // Second call should be for archived fields
    expect(customFieldsResponse).toHaveBeenCalledWith({
      fullPath: 'group/path',
      active: false,
    });
  });

  it('maintains filter state when refetching after archive', async () => {
    const customFieldsResponse = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '123',
          customFields: {
            nodes: [],
            count: 0,
          },
        },
      },
    });

    createComponent({ customFieldsResponse });
    await waitForPromises();

    await findArchivedFilterButton().vm.$emit('click');
    await waitForPromises();

    wrapper.findComponent(CustomFieldForm).vm.$emit('created');
    await waitForPromises();

    // Should maintain archived filter state
    expect(customFieldsResponse).toHaveBeenLastCalledWith({
      fullPath: 'group/path',
      active: false,
    });
  });
});
