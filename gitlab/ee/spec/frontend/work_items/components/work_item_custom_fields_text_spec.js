import { GlForm, GlFormInput, GlLink, GlTruncate } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import WorkItemCustomFieldText from 'ee/work_items/components/work_item_custom_fields_text.vue';
import { CUSTOM_FIELDS_TYPE_TEXT, CUSTOM_FIELDS_TYPE_NUMBER } from '~/work_items/constants';

describe('WorkItemCustomFieldsText', () => {
  let wrapper;

  const defaultWorkItemType = 'Task';

  const defaultField = {
    customField: {
      id: '1-text',
      fieldType: CUSTOM_FIELDS_TYPE_TEXT,
      name: 'Text custom field label',
    },
    value: 'Sample text',
  };

  const findComponent = () => wrapper.findComponent(WorkItemCustomFieldText);
  const findHeader = () => wrapper.find('h3');
  const findEditButton = () => wrapper.find('[data-testid="edit-text"]');
  const findApplyButton = () => wrapper.find('[data-testid="apply-text"]');
  const findLabel = () => wrapper.find('label');
  const findForm = () => wrapper.findComponent(GlForm);
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findLink = () => wrapper.findComponent(GlLink);
  const findText = () => wrapper.findComponent(GlTruncate);
  const findValue = () => wrapper.find('[data-testid="custom-field-value"]');

  const createComponent = ({
    canUpdate = true,
    workItemType = defaultWorkItemType,
    customField = defaultField,
  } = {}) => {
    wrapper = shallowMount(WorkItemCustomFieldText, {
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
          id: '1-number',
          fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
          name: 'Number custom field label',
        },
        value: 5,
      });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findHeader().exists()).toBe(false);
    });
  });

  describe('label', () => {
    it('shows header when not editing', async () => {
      createComponent();

      await nextTick();

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
    it('shows None when no text is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: null,
        },
      });

      expect(findValue().text()).toContain('None');
    });

    it('shows None when invalid value is received', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: 5,
        },
      });

      expect(findValue().text()).toContain('None');
    });

    it('shows text when text is set', () => {
      createComponent();

      expect(findLink().exists()).toBe(false);
      expect(findText().props().text).toContain('Sample text');
    });

    it('shows link value when link is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/41',
        },
      });

      expect(findLink().exists()).toBe(true);
      expect(findLink().attributes().href).toContain(
        'https://gitlab.com/gitlab-org/gitlab/-/work_items/41',
      );
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

  describe('custom field text input', () => {
    it('is not shown while not editing', () => {
      createComponent();

      expect(findInput().exists()).toBe(false);
    });

    it('has text-y attributes', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findInput().attributes()).toEqual(
        expect.objectContaining({
          maxlength: '540',
          placeholder: 'Enter text',
        }),
      );
    });
  });
});
