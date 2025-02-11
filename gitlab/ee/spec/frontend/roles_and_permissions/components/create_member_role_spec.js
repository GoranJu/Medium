import {
  GlFormInput,
  GlCollapsibleListbox,
  GlLoadingIcon,
  GlAlert,
  GlForm,
  GlFormGroup,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import createMemberRoleMutation from 'ee/roles_and_permissions/graphql/create_member_role.mutation.graphql';
import updateMemberRoleMutation from 'ee/roles_and_permissions/graphql/update_member_role.mutation.graphql';
import CreateMemberRole from 'ee/roles_and_permissions/components/create_member_role.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import memberRoleQuery from 'ee/roles_and_permissions/graphql/role_details/member_role.query.graphql';
import { visitUrl } from '~/lib/utils/url_utility';
import PermissionsSelector from 'ee/roles_and_permissions/components/permissions_selector.vue';
import { getMemberRoleQueryResponse } from '../mock_data';

Vue.use(VueApollo);

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

jest.mock('~/lib/utils/url_utility');

const mutationSuccessData = { data: { memberRoleSave: { errors: [] } } };

describe('CreateMemberRole', () => {
  let wrapper;

  const createMutationSuccessHandler = jest.fn().mockResolvedValue(mutationSuccessData);
  const updateMutationSuccessHandler = jest.fn().mockResolvedValue(mutationSuccessData);
  const defaultMemberRoleHandler = jest.fn().mockResolvedValue(getMemberRoleQueryResponse());

  const createComponent = ({
    createMutationMock = createMutationSuccessHandler,
    updateMutationMock = updateMutationSuccessHandler,
    memberRoleHandler = defaultMemberRoleHandler,
    groupFullPath = 'test-group',
    roleId,
  } = {}) => {
    wrapper = shallowMountExtended(CreateMemberRole, {
      propsData: { groupFullPath, listPagePath: 'http://list/page/path', roleId },
      stubs: {
        GlFormInput: stubComponent(GlFormInput, { props: ['state'] }),
        GlFormGroup: stubComponent(GlFormGroup, { props: ['state'] }),
      },
      apolloProvider: createMockApollo([
        [memberRoleQuery, memberRoleHandler],
        [createMemberRoleMutation, createMutationMock],
        [updateMemberRoleMutation, updateMutationMock],
      ]),
    });

    return waitForPromises();
  };

  const findSubmitButton = () => wrapper.findByTestId('submit-button');
  const findCancelButton = () => wrapper.findByTestId('cancel-button');
  const findNameField = () => wrapper.findAllComponents(GlFormInput).at(0);
  const findBaseRoleFormGroup = () => wrapper.findByTestId('base-role-form-group');
  const findRoleDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDescriptionField = () => wrapper.findAllComponents(GlFormInput).at(1);
  const findPermissionsSelector = () => wrapper.findComponent(PermissionsSelector);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findForm = () => wrapper.findComponent(GlForm);

  const fillForm = () => {
    findRoleDropdown().vm.$emit('select', 'GUEST');
    findNameField().vm.$emit('input', 'My role name');
    findDescriptionField().vm.$emit('input', 'My description');
    findPermissionsSelector().vm.$emit('change', ['A']);

    return nextTick();
  };

  const submitForm = (waitFn = nextTick) => {
    findForm().vm.$emit('submit', { preventDefault: () => {} });
    return waitFn();
  };

  describe('common behavior', () => {
    beforeEach(() => createComponent());

    it('shows the role dropdown with the expected options', () => {
      const expectedOptions = [
        'MINIMAL_ACCESS',
        'GUEST',
        'PLANNER',
        'REPORTER',
        'DEVELOPER',
        'MAINTAINER',
      ];

      expect(
        findRoleDropdown()
          .props('items')
          .map((role) => role.value),
      ).toStrictEqual(expectedOptions);
    });

    it('shows submit button', () => {
      expect(findSubmitButton().attributes('type')).toBe('submit');
      expect(findSubmitButton().props('variant')).toBe('confirm');
    });

    it('shows cancel button', () => {
      expect(findCancelButton().text()).toBe('Cancel');
      expect(findCancelButton().attributes('href')).toBe('http://list/page/path');
    });
  });

  describe('field validation', () => {
    beforeEach(() => createComponent());

    it('shows a warning if no base role is selected', async () => {
      expect(findBaseRoleFormGroup().props('state')).toBe(true);

      await submitForm();

      expect(findBaseRoleFormGroup().props('state')).toBe(false);
    });

    it('shows a warning if name field is empty', async () => {
      expect(findNameField().props('state')).toBe(true);

      await submitForm();

      expect(findNameField().attributes('state')).toBe(undefined);
    });

    it('shows a warning if no permissions are selected', async () => {
      expect(findPermissionsSelector().props('isValid')).toBe(true);

      findPermissionsSelector().vm.$emit('update:permissions', []);
      await submitForm();

      expect(findPermissionsSelector().props('isValid')).toBe(false);
    });
  });

  describe('create role', () => {
    beforeEach(() => createComponent());

    it('does not fetch a member role on page load when creating a role', () => {
      expect(defaultMemberRoleHandler).not.toHaveBeenCalled();
    });

    it('shows correct text on submit button', () => {
      expect(findSubmitButton().text()).toBe('Create role');
    });
  });

  describe('when create role form is submitted', () => {
    it('disables the submit and cancel buttons', async () => {
      await createComponent();
      await fillForm();
      // Verify that the buttons don't start off as disabled.
      expect(findSubmitButton().props('loading')).toBe(false);
      expect(findCancelButton().props('disabled')).toBe(false);

      await submitForm();

      expect(findSubmitButton().props('loading')).toBe(true);
      expect(findCancelButton().props('disabled')).toBe(true);
    });

    it('dismisses any previous alert', async () => {
      await createComponent({ createMutationMock: jest.fn().mockRejectedValue() });
      await fillForm();
      await submitForm(waitForPromises);

      // Verify that the first alert was created and not dismissed.
      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(mockAlertDismiss).toHaveBeenCalledTimes(0);

      await submitForm(waitForPromises);

      // Verify that the second alert was created and the first was dismissed.
      expect(createAlert).toHaveBeenCalledTimes(2);
      expect(mockAlertDismiss).toHaveBeenCalledTimes(1);
    });

    it.each(['group-path', null])(
      'calls the mutation with the correct data when groupFullPath is %s',
      async (groupFullPath) => {
        await createComponent({ groupFullPath });
        await fillForm();
        await submitForm();

        const input = {
          baseAccessLevel: 'GUEST',
          name: 'My role name',
          description: 'My description',
          permissions: ['A'],
          ...(groupFullPath ? { groupPath: groupFullPath } : {}),
        };

        expect(createMutationSuccessHandler).toHaveBeenCalledWith({ input });
      },
    );
  });

  describe('when create role succeeds', () => {
    it('redirects to the list page path', async () => {
      await createComponent();
      await fillForm();
      await submitForm(waitForPromises);

      expect(visitUrl).toHaveBeenCalledWith('http://list/page/path');
    });
  });

  describe('when there is an error creating the role', () => {
    const createMutationMock = jest
      .fn()
      .mockResolvedValue({ data: { memberRoleSave: { errors: ['reason'] } } });

    beforeEach(async () => {
      await createComponent({ createMutationMock });
      await fillForm();
    });

    it('shows an error alert', async () => {
      await submitForm(waitForPromises);

      expect(createAlert).toHaveBeenCalledWith({ message: 'Failed to create role: reason' });
    });

    it('enables the submit and cancel buttons', () => {
      expect(findSubmitButton().props('loading')).toBe(false);
      expect(findCancelButton().props('disabled')).toBe(false);
    });

    it('does not emit the success event', () => {
      expect(wrapper.emitted('success')).toBeUndefined();
    });
  });

  describe('edit role', () => {
    describe('on page load', () => {
      beforeEach(() => {
        createComponent({ roleId: 1 });
      });

      it('shows a loading spinner', () => {
        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('starts the member role query', () => {
        expect(defaultMemberRoleHandler).toHaveBeenCalledTimes(1);
        expect(defaultMemberRoleHandler).toHaveBeenCalledWith({ id: 'gid://gitlab/MemberRole/1' });
      });
    });

    describe('on role fetch error', () => {
      it('shows error message when there is no role', async () => {
        const memberRoleHandler = jest.fn().mockResolvedValue({ data: { memberRole: null } });
        await createComponent({ roleId: 1, memberRoleHandler });

        expect(findAlert().text()).toBe('Failed to load custom role.');
      });

      it('shows error message when there was an error fetching the role', async () => {
        const memberRoleHandler = jest.fn().mockRejectedValue();
        await createComponent({ roleId: 1, memberRoleHandler });

        expect(findAlert().text()).toBe('Failed to load custom role.');
      });
    });

    describe('after the member role is loaded', () => {
      beforeEach(() => {
        return createComponent({ roleId: 1 });
      });

      it('shows the form with the expected pre-filled data', () => {
        expect(findRoleDropdown().props('selected')).toBe('DEVELOPER');
        expect(findNameField().attributes('value')).toBe('Custom role');
        expect(findDescriptionField().attributes('value')).toBe('Custom role description');
        expect(findPermissionsSelector().props('permissions')).toEqual(['A', 'B']);
      });

      it('disables the base role selector', () => {
        expect(findRoleDropdown().attributes('disabled')).toBe('true');
      });

      it('shows correct text on submit button', () => {
        expect(findSubmitButton().text()).toBe('Save role');
      });
    });

    describe('saving the role', () => {
      it('calls the update mutation with the expected data', async () => {
        await createComponent({ roleId: 1 });
        await submitForm();

        expect(updateMutationSuccessHandler).toHaveBeenCalledWith({
          input: {
            id: 'gid://gitlab/MemberRole/1',
            name: 'Custom role',
            description: 'Custom role description',
            permissions: ['A', 'B'],
          },
        });
      });
    });
  });
});
