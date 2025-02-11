import { GlAlert, GlSprintf, GlTabs, GlButton, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoleDetails from 'ee/roles_and_permissions/components/role_details/role_details.vue';
import DetailsTab from 'ee/roles_and_permissions/components/role_details/details_tab.vue';
import DeleteRoleModal from 'ee/roles_and_permissions/components/delete_role_modal.vue';
import { BASE_ROLES_WITHOUT_MINIMAL_ACCESS } from '~/access_level/constants';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { visitUrl } from '~/lib/utils/url_utility';
import createMockApollo from 'helpers/mock_apollo_helper';
import memberRoleQuery from 'ee/roles_and_permissions/graphql/role_details/member_role.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { mockMemberRole, getMemberRoleQueryResponse } from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility');

const getMemberRoleHandler = (memberRole) =>
  jest.fn().mockResolvedValue(getMemberRoleQueryResponse(memberRole));
const defaultMemberRoleHandler = getMemberRoleHandler(mockMemberRole);

describe('Role details', () => {
  let wrapper;

  const createWrapper = ({
    roleId = '5',
    memberRoleHandler = defaultMemberRoleHandler,
    listPagePath = '/list/page/path',
  } = {}) => {
    wrapper = shallowMountExtended(RoleDetails, {
      apolloProvider: createMockApollo([[memberRoleQuery, memberRoleHandler]]),
      propsData: { roleId, listPagePath },
      stubs: { GlSprintf },
      directives: { GlTooltip: createMockDirective('gl-tooltip') },
    });

    return waitForPromises();
  };

  const findRoleDetails = () => wrapper.findByTestId('role-details');
  const findRoleName = () => wrapper.find('h1');
  const findHeaderDescription = () => wrapper.find('p');
  const findDetailsTab = () => wrapper.findComponent(GlTabs).findComponent(DetailsTab);
  const findEditButton = () => wrapper.findByTestId('edit-button');
  const findDeleteButtonWrapper = () => wrapper.findByTestId('delete-button');
  const findDeleteButton = () => findDeleteButtonWrapper().findComponent(GlButton);
  const findDeleteRoleModal = () => wrapper.findComponent(DeleteRoleModal);
  const getTooltip = (findFn) => getBinding(findFn().element, 'gl-tooltip');

  describe('when there is a query error', () => {
    beforeEach(() => createWrapper({ memberRoleHandler: jest.fn().mockRejectedValue('test') }));

    it('shows error alert', () => {
      const alert = wrapper.findComponent(GlAlert);

      expect(alert.text()).toBe('Failed to fetch role.');
      expect(alert.props()).toMatchObject({ variant: 'danger', dismissible: false });
    });

    it('does not show role details', () => {
      expect(findRoleDetails().exists()).toBe(false);
    });
  });

  describe('for all roles', () => {
    beforeEach(() => createWrapper());

    it('shows role details tab', () => {
      expect(findDetailsTab().props('role')).toEqual(mockMemberRole);
    });
  });

  describe('when the role is a standard role', () => {
    describe.each(BASE_ROLES_WITHOUT_MINIMAL_ACCESS)('$text', (role) => {
      beforeEach(() => createWrapper({ roleId: role.value }));

      it('does not call query', () => {
        expect(defaultMemberRoleHandler).not.toHaveBeenCalled();
      });

      it('shows role name', () => {
        expect(findRoleName().text()).toBe(role.text);
      });

      it('does not show action buttons', () => {
        expect(findEditButton().exists()).toBe(false);
        expect(findDeleteButtonWrapper().exists()).toBe(false);
      });

      it('shows header description', () => {
        expect(findHeaderDescription().text()).toBe(
          'This role is available by default and cannot be changed.',
        );
      });
    });
  });

  describe('when the role is a custom role', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('calls query', () => {
      expect(defaultMemberRoleHandler).toHaveBeenCalledTimes(1);
      expect(defaultMemberRoleHandler).toHaveBeenCalledWith({ id: 'gid://gitlab/MemberRole/5' });
    });

    it('shows loading icon', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    describe('after query is done', () => {
      beforeEach(waitForPromises);

      it('shows role name', () => {
        expect(findRoleName().text()).toBe('Custom role');
      });

      it('shows action buttons', () => {
        expect(findEditButton().exists()).toBe(true);
        expect(findDeleteButton().exists()).toBe(true);
      });

      it('shows header description', () => {
        expect(findHeaderDescription().text()).toBe('Custom role created on Aug 4, 2024');
      });
    });
  });

  describe('edit button', () => {
    beforeEach(() => createWrapper());

    it('shows button', () => {
      expect(findEditButton().attributes('href')).toBe('role/path/1/edit');
      expect(findEditButton().props('icon')).toBe('pencil');
    });

    it('shows button tooltip', () => {
      expect(getTooltip(findEditButton).value).toBe('Edit role');
    });
  });

  describe('delete button', () => {
    describe.each`
      usersCount | disabled | expectedTooltip
      ${0}       | ${false} | ${'Delete role'}
      ${1}       | ${true}  | ${{ delay: 0, title: 'To delete custom role, remove role from all users.' }}
    `(`when the role users count is usersCount`, ({ usersCount, disabled, expectedTooltip }) => {
      beforeEach(() => {
        const memberRole = { ...mockMemberRole, usersCount };
        return createWrapper({ memberRoleHandler: getMemberRoleHandler(memberRole) });
      });

      it('shows button', () => {
        expect(findDeleteButton().props()).toMatchObject({
          icon: 'remove',
          category: 'secondary',
          variant: 'danger',
          disabled,
        });
      });

      it('shows button tooltip on wrapper', () => {
        expect(getTooltip(findDeleteButtonWrapper).value).toEqual(expectedTooltip);
      });
    });
  });

  describe('delete role modal', () => {
    beforeEach(() => createWrapper());

    it('shows modal', () => {
      expect(findDeleteRoleModal().props('role')).toBe(null);
    });

    describe('when delete button is clicked', () => {
      beforeEach(() => {
        findDeleteButton().vm.$emit('click');
        return nextTick();
      });

      it('passes role to modal', () => {
        expect(findDeleteRoleModal().props('role')).toEqual(mockMemberRole);
      });

      it('clears role to delete when modal is closed', async () => {
        findDeleteRoleModal().vm.$emit('close');
        await nextTick();

        expect(findDeleteRoleModal().props('role')).toBe(null);
      });

      describe('when role is deleted', () => {
        beforeEach(() => {
          findDeleteRoleModal().vm.$emit('deleted');
          return nextTick();
        });

        it('navigates to list page', () => {
          expect(visitUrl).toHaveBeenCalledWith('/list/page/path');
        });

        it('keeps the modal open', () => {
          expect(findDeleteRoleModal().props('role')).toEqual(mockMemberRole);
        });
      });
    });
  });
});
