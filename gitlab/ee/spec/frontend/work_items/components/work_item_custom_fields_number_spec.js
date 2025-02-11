import { GlForm, GlFormInput } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import WorkItemCustomFieldNumber from 'ee/work_items/components/work_item_custom_fields_number.vue';
import { CUSTOM_FIELDS_TYPE_NUMBER, CUSTOM_FIELDS_TYPE_TEXT } from '~/work_items/constants';

describe('WorkItemCustomFieldsNumber', () => {
  let wrapper;

  const defaultWorkItemType = 'Task';

  const defaultField = {
    customField: {
      id: '1-number',
      fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
      name: 'Number custom field label',
    },
    value: 5,
  };

  const findComponent = () => wrapper.findComponent(WorkItemCustomFieldNumber);
  const findHeader = () => wrapper.find('h3');
  const findEditButton = () => wrapper.find('[data-testid="edit-number"]');
  const findApplyButton = () => wrapper.find('[data-testid="apply-number"]');
  const findLabel = () => wrapper.find('label');
  const findForm = () => wrapper.findComponent(GlForm);
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findValue = () => wrapper.find('[data-testid="custom-field-value"]');

  const createComponent = ({
    canUpdate = true,
    workItemType = defaultWorkItemType,
    customField = defaultField,
  } = {}) => {
    wrapper = shallowMount(WorkItemCustomFieldNumber, {
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
      expect(findHeader().exists()).toBe(true);
    });

    it('does not render if custom field is empty', async () => {
      createComponent({ customField: {} });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findHeader().exists()).toBe(false);
    });

    it('does not render if custom field type is incorrect', async () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: 'Sample text',
        },
      });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findHeader().exists()).toBe(false);
    });
  });

  describe('label', () => {
    it('shows header when not editing', () => {
      createComponent();

      expect(findHeader().exists()).toBe(true);
      expect(findHeader().classes('gl-sr-only')).toBe(false);
      expect(findLabel().exists()).toBe(false);
    });

    it('shows label and hides header while editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findLabel().exists()).toBe(true);
      expect(findHeader().classes('gl-sr-only')).toBe(true);
    });
  });

  describe('edit button', () => {
    it('is not shown if user cannot edit', () => {
      createComponent({ canUpdate: false });

      expect(findEditButton().exists()).toBe(false);
    });

    it('is shown if user can edit', () => {
      createComponent({ canUpdate: true });

      expect(findEditButton().exists()).toBe(true);
    });

    it('triggers edit mode on click', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findLabel().exists()).toBe(true);
      expect(findForm().exists()).toBe(true);
    });

    it('is replaced by Apply button while editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findEditButton().exists()).toBe(false);
      expect(findApplyButton().exists()).toBe(true);
    });
  });

  describe('value', () => {
    it('shows value when number is set', () => {
      createComponent();

      expect(findValue().text()).toContain('5');
    });

    it('shows None when no number is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-number',
            fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
            name: 'Number custom field label',
          },
          value: null,
        },
      });

      expect(findValue().text()).toContain('None');
    });

    it('shows None when invalid value type is received', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-number',
            fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
            name: 'Number custom field label',
          },
          value: 'Text',
        },
      });

      expect(findValue().text()).toContain('None');
    });
  });

  describe('form', () => {
    it('is not shown while not editing', () => {
      createComponent();

      expect(findForm().exists()).toBe(false);
    });

    it('is shown while editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findForm().exists()).toBe(true);
    });
  });

  describe('custom field number input', () => {
    it('is not shown while not editing', () => {
      createComponent();

      expect(findInput().exists()).toBe(false);
    });

    it('has number-y attributes', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findInput().attributes()).toEqual(
        expect.objectContaining({
          min: '0',
          type: 'number',
        }),
      );
    });
  });
});
