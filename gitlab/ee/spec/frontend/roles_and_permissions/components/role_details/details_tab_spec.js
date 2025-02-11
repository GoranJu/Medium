import { GlSprintf, GlSkeletonLoader, GlIcon } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DetailsTab from 'ee/roles_and_permissions/components/role_details/details_tab.vue';
import { BASE_ROLES } from '~/access_level/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import permissionsQuery from 'ee/roles_and_permissions/graphql/member_role_permissions.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { mockMemberRole, mockPermissionsResponse, mockDefaultPermissions } from '../../mock_data';

Vue.use(VueApollo);
global.gon = { relative_url_root: '' };

jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');
jest.mock('~/helpers/help_page_helper', () => ({
  helpPagePath: (path) => path,
}));

const defaultPermissionsHandler = jest.fn().mockResolvedValue(mockPermissionsResponse);

const enabledPermissions = mockDefaultPermissions.slice(0, 2);
const disabledPermissions = mockDefaultPermissions.slice(2);

describe('Role details tab', () => {
  let wrapper;

  const createWrapper = ({
    role = mockMemberRole,
    permissionsHandler = defaultPermissionsHandler,
  } = {}) => {
    wrapper = shallowMountExtended(DetailsTab, {
      apolloProvider: createMockApollo([[permissionsQuery, permissionsHandler]]),
      propsData: { role },
      stubs: { GlSprintf },
    });

    return waitForPromises();
  };

  const findHeader = (name) => wrapper.findByTestId(`${name}-header`);
  const findValue = (name) => wrapper.findByTestId(`${name}-value`);
  const findHeaderText = (name) => findHeader(name).text();
  const findValueText = (name) => findValue(name).text();
  const findViewPermissionsButton = () => wrapper.findByTestId('view-permissions-button');
  const findAllPermissions = () => wrapper.findAllByTestId('permission');
  const findPermissionFor = (value) => wrapper.findByTestId(`permission-${value}`);
  const findPermissionIconFor = (value) => findPermissionFor(value).findComponent(GlIcon);
  const findPermissionsSkeletonLoader = () =>
    wrapper.findByTestId('custom-permissions-list').findComponent(GlSkeletonLoader);

  describe('for all role types', () => {
    beforeEach(() => createWrapper());

    it('shows role type header', () => {
      expect(findHeaderText('type')).toBe('Role type');
    });

    it('shows role description header', () => {
      expect(findHeaderText('description')).toBe('Description');
    });

    it('shows view permissions button', () => {
      expect(findViewPermissionsButton().text()).toBe('View permissions');
      expect(findViewPermissionsButton().attributes('href')).toBe('user/permissions');
      expect(findViewPermissionsButton().props()).toMatchObject({
        icon: 'external-link',
        variant: 'link',
        target: '_blank',
      });
    });
  });

  describe('for default roles', () => {
    describe.each(BASE_ROLES)('$text', (role) => {
      beforeEach(() => createWrapper({ role }));

      it('does not call permissions query', () => {
        expect(defaultPermissionsHandler).not.toHaveBeenCalled();
      });

      it('shows role ID header', () => {
        expect(findHeaderText('id')).toBe('Access level');
      });

      it('shows role ID', () => {
        expect(findValueText('id')).toBe(role.accessLevel.toString());
      });

      it('shows role type', () => {
        expect(findValueText('type')).toBe('Default');
      });

      it('shows role description', () => {
        expect(findValueText('description')).toBe(role.description);
      });

      it('does not show base role', () => {
        expect(findHeader('base-role').exists()).toBe(false);
        expect(findValue('base-role').exists()).toBe(false);
      });

      it('does not show custom permissions', () => {
        expect(findHeader('custom-permissions').exists()).toBe(false);
        expect(findValue('custom-permissions').exists()).toBe(false);
      });
    });
  });

  describe('for custom role', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('calls permissions query', () => {
      expect(defaultPermissionsHandler).toHaveBeenCalledTimes(1);
      expect(defaultPermissionsHandler).toHaveBeenCalledWith({ includeDescription: false });
    });

    it('shows role ID header', () => {
      expect(findHeaderText('id')).toBe('Role ID');
    });

    it('shows role ID', () => {
      expect(findValueText('id')).toBe('1');
    });

    it('shows role type', () => {
      expect(findValueText('type')).toBe('Custom');
    });

    it('shows role description', () => {
      expect(findValueText('description')).toBe('Custom role description');
    });

    it('shows base role', () => {
      expect(findHeaderText('base-role')).toBe('Base role');
      expect(findValueText('base-role')).toBe('Developer');
    });

    describe('custom permissions', () => {
      it('shows header', () => {
        expect(findHeaderText('custom-permissions')).toBe('Custom permissions');
      });

      it('shows skeleton loader', () => {
        expect(findPermissionsSkeletonLoader().exists()).toBe(true);
      });

      it('does not show custom permissions', () => {
        expect(findAllPermissions()).toHaveLength(0);
      });

      describe('after query is done loading', () => {
        beforeEach(() => waitForPromises());

        it('does not show loading icon', () => {
          expect(findPermissionsSkeletonLoader().exists()).toBe(false);
        });

        it('shows custom permissions count', () => {
          expect(findValueText('custom-permissions')).toBe('2 of 7 permissions added');
        });

        describe.each(enabledPermissions)('for permission $name', ({ name, value }) => {
          it('shows icon', () => {
            expect(findPermissionIconFor(value).props()).toMatchObject({
              name: 'check-sm',
              variant: 'success',
            });
          });

          it('shows permission name', () => {
            expect(findPermissionFor(value).text()).toBe(name);
          });

          it('does not have light gray text color', () => {
            expect(findPermissionFor(value).classes('gl-text-subtle')).toBe(false);
          });
        });

        describe.each(disabledPermissions)('for permission $name', ({ name, value }) => {
          it('shows icon', () => {
            expect(findPermissionIconFor(value).props()).toMatchObject({
              name: 'merge-request-close-m',
              variant: 'disabled',
            });
          });

          it('shows permission name', () => {
            expect(findPermissionFor(value).text()).toBe(name);
          });

          it('has light gray text color', () => {
            expect(findPermissionFor(value).classes('gl-text-subtle')).toBe(true);
          });
        });
      });
    });
  });

  describe('when there is an error fetching permissions', () => {
    beforeEach(() => createWrapper({ permissionsHandler: jest.fn().mockRejectedValue() }));

    it('shows error alert', () => {
      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Could not fetch available permissions.',
      });
    });

    it('does not show any permissions', () => {
      expect(findAllPermissions()).toHaveLength(0);
    });
  });
});
