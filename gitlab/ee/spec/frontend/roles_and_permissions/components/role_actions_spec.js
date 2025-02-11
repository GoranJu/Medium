import { GlDisclosureDropdown, GlIcon, GlLink, GlPopover, GlTooltip } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RoleActions from 'ee/roles_and_permissions/components/role_actions.vue';
import { mockMemberRole } from '../mock_data';

describe('Role actions', () => {
  let wrapper;

  const mockToastShow = jest.fn();
  const defaultRole = { accessLevel: 10 };
  const customRole = {
    ...mockMemberRole,
    detailsPath: 'role/path/1',
    dependentSecurityPolicies: [],
  };
  const customRoleWithMembers = { ...customRole, usersCount: 2 };
  const dependentSecurityPolicy = { editPath: 'path/to/security/policy', name: 'Security Policy' };
  const customRoleWithSecurityPolicies = {
    ...customRole,
    usersCount: 2,
    dependentSecurityPolicies: [dependentSecurityPolicy],
  };

  const createComponent = ({ role = customRole } = {}) => {
    wrapper = mountExtended(RoleActions, {
      propsData: { role },
      mocks: { $toast: { show: mockToastShow } },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findRoleIdItem = () => wrapper.findByTestId('role-id-item');
  const findViewDetailsItem = () => wrapper.findByTestId('view-details-item');
  const findEditRoleItem = () => wrapper.findByTestId('edit-role-item');
  const findDeleteRoleItem = () => wrapper.findByTestId('delete-role-item');
  const findDeleteRoleItemTooltip = () => wrapper.findComponent(GlTooltip);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findLink = () => wrapper.findComponent(GlLink);

  describe('common behavior', () => {
    beforeEach(() => createComponent());

    it('renders the actions dropdown', () => {
      expect(findDropdown().props()).toMatchObject({
        icon: 'ellipsis_v',
        category: 'tertiary',
        noCaret: true,
      });
    });

    it('shows View details item', () => {
      expect(findViewDetailsItem().props('item')).toMatchObject({
        text: 'View details',
        href: 'role/path/1',
      });
    });

    it('does not render the popover', () => {
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe.each`
    type         | role           | id      | expectedText          | expectedToast
    ${'default'} | ${defaultRole} | ${'10'} | ${'Access level: 10'} | ${'Access level copied to clipboard'}
    ${'custom'}  | ${customRole}  | ${'1'}  | ${'Role ID: 1'}       | ${'Role ID copied to clipboard'}
  `('role ID item for $type role', ({ role, id, expectedText, expectedToast }) => {
    beforeEach(() => createComponent({ role }));

    it('shows clipboard icon', () => {
      expect(findRoleIdItem().findComponent(GlIcon).props('name')).toBe('copy-to-clipboard');
    });

    it('shows role ID', () => {
      expect(findRoleIdItem().attributes('data-clipboard-text')).toBe(id);
      expect(findRoleIdItem().text()).toBe(expectedText);
    });

    it('shows copied to clipboard toast when clicked', async () => {
      findRoleIdItem().vm.$emit('action');
      await nextTick();

      expect(mockToastShow).toHaveBeenCalledWith(expectedToast);
    });
  });

  describe('for default role', () => {
    beforeEach(() => createComponent({ role: defaultRole }));

    it('does not show Edit role item', () => {
      expect(findEditRoleItem().exists()).toBe(false);
    });

    it('does not show Delete role item', () => {
      expect(findDeleteRoleItem().exists()).toBe(false);
    });
  });

  describe('for custom role', () => {
    beforeEach(() => createComponent());

    it('shows Edit role item', () => {
      expect(findEditRoleItem().props('item')).toMatchObject({
        text: 'Edit role',
        href: 'role/path/1/edit',
      });
    });

    describe('delete role item', () => {
      describe('default', () => {
        it('shows item', () => {
          expect(findDeleteRoleItem().props('item')).toMatchObject({
            text: 'Delete role',
            extraAttrs: { disabled: false, class: '!gl-text-red-500' },
          });
        });

        it('does not have tooltip', () => {
          expect(findDeleteRoleItemTooltip().exists()).toBe(false);
        });

        it('emits delete event when clicked', async () => {
          findDeleteRoleItem().vm.$emit('action');
          await nextTick();

          expect(wrapper.emitted('delete')).toHaveLength(1);
        });
      });

      describe('when there are members assigned', () => {
        beforeEach(() => createComponent({ role: customRoleWithMembers }));

        it('shows item', () => {
          expect(findDeleteRoleItem().props('item')).toMatchObject({
            extraAttrs: { disabled: true, class: '' },
          });
        });

        it('has expected tooltip', () => {
          expect(findDeleteRoleItemTooltip().exists()).toBe(true);
          expect(findDeleteRoleItemTooltip().props()).toEqual(
            expect.objectContaining({
              placement: 'left',
              boundary: 'viewport',
            }),
          );
          expect(findDeleteRoleItemTooltip().text()).toBe(
            "You can't delete this custom role until you remove it from all group members.",
          );
        });
      });

      describe('when there are dependent security policies', () => {
        beforeEach(() => createComponent({ role: customRoleWithSecurityPolicies }));

        it('disables the delete button', () => {
          expect(findDeleteRoleItem().props('item')).toMatchObject({
            extraAttrs: { disabled: true, class: '' },
          });
        });

        it('does not render the tooltip', () => {
          expect(findDeleteRoleItemTooltip().exists()).toBe(false);
        });

        it('renders the popover', () => {
          expect(findPopover().exists()).toBe(true);
          expect(findPopover().text()).toContain(
            "You can't delete this custom role until you remove it from all security policies:",
          );
        });

        it('renders the policy name as a link', () => {
          expect(findLink().attributes('href')).toBe(dependentSecurityPolicy.editPath);
          expect(findLink().text()).toBe(dependentSecurityPolicy.name);
        });
      });
    });
  });
});
