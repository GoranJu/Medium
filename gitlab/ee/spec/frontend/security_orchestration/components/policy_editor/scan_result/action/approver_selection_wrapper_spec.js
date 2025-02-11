import { nextTick } from 'vue';
import { GlForm, GlCollapsibleListbox, GlSprintf, GlBadge } from '@gitlab/ui';
import { trimText } from 'helpers/text_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { GROUP_TYPE, ROLE_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import ApproverSelectionWrapper from 'ee/security_orchestration/components/policy_editor/scan_result/action/approver_selection_wrapper.vue';
import GroupSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/group_select.vue';
import UserSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/user_select.vue';
import {
  APPROVER_TYPE_LIST_ITEMS,
  DEFAULT_APPROVER_DROPDOWN_TEXT,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/actions';

describe('ApproverSelectionWrapper', () => {
  let wrapper;

  const factory = ({ propsData = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(ApproverSelectionWrapper, {
      propsData: {
        availableTypes: APPROVER_TYPE_LIST_ITEMS,
        approverIndex: 0,
        approvalsRequired: 1,
        existingApprovers: {},
        numOfApproverTypes: 1,
        ...propsData,
      },
      provide: {
        namespaceId: '1',
        namespacePath: 'path/to/project',
        namespaceType: 'project',
      },
      stubs: {
        GlForm,
        GlSprintf,
        SectionLayout,
        ...stubs,
      },
    });
  };

  const findApproverTypeDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findGroupSelect = () => wrapper.findComponent(GroupSelect);
  const findUserSelect = () => wrapper.findComponent(UserSelect);
  const findAddButton = () => wrapper.findByTestId('add-approver');
  const findApproverTypeDropdownContent = () => wrapper.findByTestId('list-item-content');
  const findApproverTypeDropdownText = () => wrapper.findByTestId('list-item-text');
  const findSectionLayout = () => wrapper.findComponent(SectionLayout);

  describe('single type', () => {
    beforeEach(factory);

    it('renders the approver type dropdown with the correct props', () => {
      expect(findApproverTypeDropdown().props()).toMatchObject({
        disabled: false,
        selected: [],
        toggleText: DEFAULT_APPROVER_DROPDOWN_TEXT,
      });
    });

    it('renders the add button', () => {
      expect(findAddButton().exists()).toBe(true);
    });

    it('triggers an update when adding a new type', async () => {
      expect(wrapper.emitted('addApproverType')).toEqual(undefined);
      await findAddButton().vm.$emit('click');
      expect(wrapper.emitted('addApproverType')).toEqual([[]]);
    });

    it('does not render the remove button', () => {
      expect(findSectionLayout().props('showRemoveButton')).toBe(false);
    });

    it('does not render the user select when the "user" type approver is not selected', () => {
      expect(findUserSelect().exists()).toBe(false);
    });

    it('does not render the group select when the "group" type approver is not selected', () => {
      expect(findGroupSelect().exists()).toBe(false);
    });

    it('triggers an update when changing the approver type', async () => {
      await findApproverTypeDropdown().vm.$emit('select', GROUP_TYPE);

      expect(wrapper.emitted()).toEqual({
        updateApproverType: [[{ newApproverType: GROUP_TYPE, oldApproverType: '' }]],
      });
    });
  });

  describe('errors', () => {
    it('renders the approver dropdown with an invalid state', () => {
      factory({ propsData: { approverType: USER_TYPE, isApproverFieldValid: false } });
      expect(findUserSelect().props('state')).toBe(false);
    });
  });

  describe('selected approver types', () => {
    it('renders the approver type dropdown with the correct props', async () => {
      factory({ propsData: { approverType: USER_TYPE } });
      await nextTick();
      const text = APPROVER_TYPE_LIST_ITEMS.find((v) => v.value === USER_TYPE)?.text;
      expect(findApproverTypeDropdown().props()).toMatchObject({
        disabled: false,
        selected: text,
        toggleText: text,
      });
    });

    it('renders the user select with the correct props when the "user" type approver is selected', async () => {
      factory({ propsData: { approverType: USER_TYPE } });
      await nextTick();
      expect(findUserSelect().exists()).toBe(true);
      expect(findUserSelect().props('state')).toBe(true);
    });

    it('renders the group select when the "group" type approver is selected', async () => {
      factory({ propsData: { approverType: GROUP_TYPE } });
      await nextTick();
      expect(findGroupSelect().exists()).toBe(true);
    });

    it('triggers an update when changing available user approvers', async () => {
      factory({ propsData: { approverType: USER_TYPE } });
      await nextTick();
      const newUser = { id: 1, type: USER_TYPE };

      await findUserSelect().vm.$emit('updateSelectedApprovers', [newUser]);

      expect(wrapper.emitted()).toEqual({
        updateApprovers: [[{ [USER_TYPE]: [{ id: newUser.id, type: USER_TYPE }] }]],
      });
    });

    it('triggers an update when changing available group approvers', async () => {
      factory({ propsData: { approverType: GROUP_TYPE } });
      await nextTick();
      const newGroup = { id: 1, type: GROUP_TYPE };

      await findGroupSelect().vm.$emit('updateSelectedApprovers', [newGroup]);

      expect(wrapper.emitted()).toEqual({
        updateApprovers: [[{ [GROUP_TYPE]: [{ id: newGroup.id, type: GROUP_TYPE }] }]],
      });
    });
  });

  describe('multiple types', () => {
    beforeEach(() => {
      factory({
        propsData: { approverIndex: 1, numOfApproverTypes: 3 },
      });
    });

    it('triggers an update when removing a new type', async () => {
      expect(wrapper.emitted('removeApproverType')).toEqual(undefined);
      await findSectionLayout().vm.$emit('remove');
      expect(wrapper.emitted('removeApproverType')).toEqual([['']]);
    });

    it('does not render the add button for the last type', () => {
      expect(findAddButton().exists()).toBe(false);
    });

    it('renders the remove button', () => {
      factory({ propsData: { showRemoveButton: true } });
      expect(findSectionLayout().props('showRemoveButton')).toBe(true);
    });
  });

  describe('message', () => {
    it('renders the correct text for when there are multiple approvers', async () => {
      await factory({
        propsData: { approverIndex: 1, numOfApproverTypes: 2, showAdditionalApproverText: true },
        stubs: { SectionLayout: true },
      });
      expect(trimText(findSectionLayout().text())).toBe('or Add new approver');
    });
  });

  describe('approve type selector', () => {
    it('renders the approve type selector', () => {
      factory();
      expect(findApproverTypeDropdown().exists()).toBe(true);
      expect(findApproverTypeDropdown().props('items')).toEqual(
        APPROVER_TYPE_LIST_ITEMS.map((item) => ({ ...item, disabled: false })),
      );
    });

    it('marks as disabled already selected items with selected items', () => {
      factory({
        propsData: {
          availableTypes: [APPROVER_TYPE_LIST_ITEMS[0], APPROVER_TYPE_LIST_ITEMS[1]],
          existingApprovers: {
            [GROUP_TYPE]: [{ id: 1, type: GROUP_TYPE }],
          },
        },
        stubs: { GlCollapsibleListbox },
      });

      expect(findApproverTypeDropdown().findComponent(GlBadge).attributes('title')).toBe(
        'You can select this option only once.',
      );
      expect(findApproverTypeDropdown().findComponent(GlBadge).text()).toBe('disabled');
      expect(findApproverTypeDropdown().props('items')[2]).toEqual({
        text: 'Groups',
        value: GROUP_TYPE,
        disabled: true,
      });
    });

    it('does not mark as disabled already selected items without selected items', () => {
      factory({
        propsData: {
          availableTypes: [APPROVER_TYPE_LIST_ITEMS[0], APPROVER_TYPE_LIST_ITEMS[1]],
        },
        stubs: { GlCollapsibleListbox },
      });

      expect(findApproverTypeDropdown().findComponent(GlBadge).exists()).toBe(false);
    });

    it('does not emit event for already selected item', () => {
      factory({
        propsData: {
          availableTypes: [APPROVER_TYPE_LIST_ITEMS[0], APPROVER_TYPE_LIST_ITEMS[1]],
        },
      });

      findApproverTypeDropdown().vm.$emit('select', GROUP_TYPE);

      expect(wrapper.emitted('updateApproverType')).toBeUndefined();

      findApproverTypeDropdown().vm.$emit('select', USER_TYPE);

      expect(wrapper.emitted('updateApproverType')).toEqual([
        [{ newApproverType: 'user', oldApproverType: '' }],
      ]);
    });

    it('does not render disable state when items are not selected', () => {
      factory({
        stubs: { GlCollapsibleListbox },
      });

      expect(findApproverTypeDropdownContent().classes()).not.toContain('!gl-cursor-default');
      expect(findApproverTypeDropdownText().classes()).not.toContain('gl-text-subtle');
    });

    it('renders disable state when items are not selected', () => {
      factory({
        propsData: {
          availableTypes: [APPROVER_TYPE_LIST_ITEMS[1], APPROVER_TYPE_LIST_ITEMS[2]],
          existingApprovers: {
            [ROLE_TYPE]: [{ id: 1, type: ROLE_TYPE }],
          },
        },
        stubs: { GlCollapsibleListbox },
      });

      expect(findApproverTypeDropdownContent().classes()).toContain('!gl-cursor-default');
      expect(findApproverTypeDropdownText().classes()).toContain('gl-text-subtle');
    });
  });
});
