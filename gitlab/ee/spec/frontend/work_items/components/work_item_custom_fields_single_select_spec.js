import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import WorkItemCustomFieldsSingleSelect from 'ee/work_items/components/work_item_custom_fields_single_select.vue';
import {
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
  CUSTOM_FIELDS_TYPE_NUMBER,
} from '~/work_items/constants';

describe('WorkItemCustomFieldsSingleSelect', () => {
  let wrapper;

  const defaultWorkItemType = 'Issue';

  const defaultField = {
    customField: {
      id: '1-select',
      fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
      name: 'Single select custom field label',
      selectOptions: [
        {
          id: 'select-1',
          value: 'Option 1',
        },
        {
          id: 'select-2',
          value: 'Option 2',
        },
        {
          id: 'select-3',
          value: 'Option 3',
        },
      ],
    },
    selectedOptions: [
      {
        id: 'select-1',
        value: 'Option 1',
      },
    ],
  };

  const findComponent = () => wrapper.findComponent(WorkItemCustomFieldsSingleSelect);
  const findSidebarDropdownWidget = () => wrapper.findComponent(WorkItemSidebarDropdownWidget);

  const createComponent = ({
    canUpdate = true,
    workItemType = defaultWorkItemType,
    customField = defaultField,
  } = {}) => {
    wrapper = shallowMount(WorkItemCustomFieldsSingleSelect, {
      propsData: {
        canUpdate,
        customField,
        workItemType,
      },
    });
  };

  describe('rendering', () => {
    it('renders if custom field exists and type is correct', async () => {
      createComponent();

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(true);
    });

    it('does not render if custom field is empty', async () => {
      createComponent({ customField: {} });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(false);
    });

    it('does not render if custom field type is incorrect', async () => {
      createComponent({
        customField: {
          id: '1-number',
          fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
          name: 'Number custom field label',
          selectOptions: null,
        },
        value: 5,
      });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(false);
    });
  });

  it('displays correct label', () => {
    createComponent();

    expect(findSidebarDropdownWidget().props('dropdownLabel')).toBe(
      'Single select custom field label',
    );
  });

  describe('value', () => {
    it('shows None when no option is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            name: 'Single select custom field label',
            selectOptions: [
              {
                id: 'select-1',
                value: 'Option 1',
              },
              {
                id: 'select-2',
                value: 'Option 2',
              },
              {
                id: 'select-3',
                value: 'Option 3',
              },
            ],
          },
          value: null,
        },
      });

      expect(findSidebarDropdownWidget().props().toggleDropdownText).toContain('None');
    });

    it('shows None when invalid value is received', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            name: 'Single select custom field label',
            selectOptions: [
              {
                id: 'select-1',
                value: 'Option 1',
              },
              {
                id: 'select-2',
                value: 'Option 2',
              },
              {
                id: 'select-3',
                value: 'Option 3',
              },
            ],
          },
          value: 'Sample text',
        },
      });

      expect(findSidebarDropdownWidget().props().toggleDropdownText).toContain('None');
    });

    it('shows option selected when is set', () => {
      createComponent();

      expect(findSidebarDropdownWidget().props().toggleDropdownText).toContain('Option 1');
    });
  });

  describe('Dropdown options', () => {
    it('shows selected option on value when dropdown is open', () => {
      createComponent();

      expect(findSidebarDropdownWidget().props('toggleDropdownText')).toBe('Option 1');
      expect(findSidebarDropdownWidget().props('itemValue')).toBe('select-1');
    });

    it('shows "None" on value when dropdown is open and no option was selected', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            name: 'Single select custom field label',
            selectOptions: [
              {
                id: 'select-1',
                value: 'Option 1',
              },
              {
                id: 'select-2',
                value: 'Option 2',
              },
              {
                id: 'select-3',
                value: 'Option 3',
              },
            ],
          },
          value: null,
        },
      });

      expect(findSidebarDropdownWidget().props('toggleDropdownText')).toBe('None');
    });

    it('shows dropdown options on list according to their state', () => {
      createComponent();

      expect(findSidebarDropdownWidget().props('listItems')).toEqual([
        { options: [{ text: 'Option 1', value: 'select-1' }], text: 'Selected' },
        {
          options: [
            { text: 'Option 2', value: 'select-2' },
            { text: 'Option 3', value: 'select-3' },
          ],
          text: 'All',
          textSrOnly: true,
        },
      ]);
    });
  });
});
