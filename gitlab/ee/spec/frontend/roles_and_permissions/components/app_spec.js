import { GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import groupRolesQuery from 'ee/roles_and_permissions/graphql/group_roles.query.graphql';
import instanceRolesQuery from 'ee/roles_and_permissions/graphql/instance_roles.query.graphql';
import RolesApp from 'ee/roles_and_permissions/components/app.vue';
import RolesTable from 'ee/roles_and_permissions/components/roles_table.vue';
import DeleteRoleModal from 'ee/roles_and_permissions/components/delete_role_modal.vue';
import RolesExport from 'ee/roles_and_permissions/components/roles_export.vue';
import { createAlert } from '~/alert';
import {
  standardRoles,
  memberRoles,
  groupRolesResponse,
  instanceRolesResponse,
} from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('Roles app', () => {
  let wrapper;

  const mockToastShow = jest.fn();
  const groupRolesSuccessQueryHandler = jest.fn().mockResolvedValue(groupRolesResponse);
  const instanceRolesSuccessQueryHandler = jest.fn().mockResolvedValue(instanceRolesResponse);

  const createComponent = ({
    groupRolesQueryHandler = groupRolesSuccessQueryHandler,
    instanceRolesQueryHandler = instanceRolesSuccessQueryHandler,
    groupFullPath = 'test-group',
    newRolePath = 'new/role/path',
    membersPermissionsDetailedExport = true,
    exportGroupMemberships = true,
  } = {}) => {
    wrapper = shallowMountExtended(RolesApp, {
      apolloProvider: createMockApollo([
        [groupRolesQuery, groupRolesQueryHandler],
        [instanceRolesQuery, instanceRolesQueryHandler],
      ]),
      provide: {
        glFeatures: { membersPermissionsDetailedExport },
        glAbilities: { exportGroupMemberships },
      },
      propsData: { groupFullPath, newRolePath },
      stubs: { GlSprintf },
      mocks: { $toast: { show: mockToastShow } },
    });

    return waitForPromises();
  };

  const findRolesTable = () => wrapper.findComponent(RolesTable);
  const findRoleCounts = () => wrapper.findByTestId('role-counts');
  const findDeleteModal = () => wrapper.findComponent(DeleteRoleModal);
  const findRolesExport = () => wrapper.findComponent(RolesExport);

  describe('common behavior', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the title', () => {
      expect(wrapper.find('h2').text()).toBe('Roles and permissions');
    });

    it('shows the New role button', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.text()).toBe('New role');
      expect(button.props('variant')).toBe('confirm');
      expect(button.attributes('href')).toBe('new/role/path');
    });

    describe('sub-title', () => {
      it('shows the sub-title', () => {
        expect(wrapper.find('p').text()).toBe(
          'Manage which actions users can take with roles and permissions.',
        );
      });

      it('links to the docs page', () => {
        const link = wrapper.findComponent(GlLink);

        expect(link.text()).toBe('roles and permissions');
        expect(link.attributes()).toMatchObject({
          href: '/help/user/permissions',
          target: '_blank',
        });
      });
    });

    describe('roles table busy state', () => {
      it('shows table as busy on page load', () => {
        expect(findRolesTable().props('busy')).toBe(true);
      });

      it('shows table as not busy after roles data is loaded', async () => {
        await waitForPromises();

        expect(findRolesTable().props('busy')).toBe(false);
      });
    });
  });

  describe.each`
    type          | groupFullPath   | queryHandler                        | expectedQueryData
    ${'group'}    | ${'test-group'} | ${groupRolesSuccessQueryHandler}    | ${{ fullPath: 'test-group' }}
    ${'instance'} | ${null}         | ${instanceRolesSuccessQueryHandler} | ${{}}
  `('for $type-level roles', ({ groupFullPath, queryHandler, expectedQueryData }) => {
    beforeEach(() => createComponent({ groupFullPath }));

    it('fetches roles', () => {
      expect(queryHandler).toHaveBeenCalledWith(expectedQueryData);
    });

    it('shows expected role counts', () => {
      expect(findRoleCounts().text()).toBe('Roles: 2 Custom 6 Default');
    });

    // Remove the Minimal Access role from standardRoles with slice(), it shouldn't be shown.
    it.each(standardRoles.slice(1))(`passes '$name' role to roles table`, (role) => {
      expect(findRolesTable().props('roles')).toContainEqual(role);
    });

    it.each(memberRoles)(`passes '$name' to roles table`, (role) => {
      expect(findRolesTable().props('roles')).toContainEqual(role);
    });

    it('does not show Minimal Access role', () => {
      expect(findRolesTable().props('roles')).not.toContainEqual(
        expect.objectContaining({ name: 'Minimal Access' }),
      );
    });
  });

  describe('when there is a query error', () => {
    it('shows an error message', async () => {
      await createComponent({ groupRolesQueryHandler: jest.fn().mockRejectedValue() });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to fetch roles.',
        dismissible: false,
      });
    });
  });

  describe('delete role modal', () => {
    beforeEach(() => createComponent());

    it('renders modal', () => {
      expect(findDeleteModal().exists()).toBe(true);
    });

    describe('when table wants to delete a role', () => {
      beforeEach(() => {
        findRolesTable().vm.$emit('delete-role', memberRoles[0]);
      });

      it('passes role to delete modal', () => {
        expect(findDeleteModal().props('role')).toBe(memberRoles[0]);
      });

      it('closes modal when modal emits close event', async () => {
        findDeleteModal().vm.$emit('close');
        await nextTick();

        expect(findDeleteModal().props('role')).toBe(null);
      });
    });

    describe('when modal finishes deleting a role', () => {
      beforeEach(() => {
        findDeleteModal().vm.$emit('deleted');
      });

      it('shows toast', () => {
        expect(mockToastShow).toHaveBeenCalledWith('Role successfully deleted.');
      });

      it('closes modal', () => {
        expect(findDeleteModal().props('role')).toBe(null);
      });

      it('refetches custom roles query', () => {
        expect(groupRolesSuccessQueryHandler).toHaveBeenCalledTimes(2);
      });
    });
  });

  describe('when newRolePath is not set', () => {
    beforeEach(() => {
      createComponent({ newRolePath: null });
    });

    it('does not show the New role button', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.exists()).toBe(false);
    });
  });

  describe('roles export', () => {
    it('does not show roles export when user does not have the ability to export', () => {
      createComponent({ exportGroupMemberships: false });

      expect(findRolesExport().exists()).toBe(false);
    });

    it('does not show roles export when membersPermissionsDetailedExport feature flag is off', () => {
      createComponent({ membersPermissionsDetailedExport: false });

      expect(findRolesExport().exists()).toBe(false);
    });

    it('shows roles export when user has ability to export', () => {
      createComponent({ exportGroupMemberships: true });

      expect(findRolesExport().exists()).toBe(true);
    });
  });
});
