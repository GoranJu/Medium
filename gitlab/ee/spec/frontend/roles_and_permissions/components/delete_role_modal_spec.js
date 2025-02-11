import { GlModal, GlAlert } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import DeleteRoleModal from 'ee/roles_and_permissions/components/delete_role_modal.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import deleteMemberRoleMutation from 'ee/roles_and_permissions/graphql/delete_member_role.mutation.graphql';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

const defaultRole = { id: 5 };

const getDeleteMutationHandler = (error) =>
  jest.fn().mockResolvedValue({ data: { memberRoleDelete: { errors: error ? [error] : [] } } });

const defaultDeleteMutationHandler = getDeleteMutationHandler();

describe('Delete role modal', () => {
  let wrapper;

  const createComponent = ({
    role = defaultRole,
    deleteMutationHandler = defaultDeleteMutationHandler,
  } = {}) => {
    wrapper = shallowMount(DeleteRoleModal, {
      propsData: { role },
      apolloProvider: createMockApollo([[deleteMemberRoleMutation, deleteMutationHandler]]),
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findAlert = () => wrapper.findComponent(GlAlert);

  describe('on creation', () => {
    beforeEach(() => createComponent());

    it('shows modal title', () => {
      expect(findModal().attributes('title')).toEqual('Delete custom role?');
    });

    it('shows modal text', () => {
      expect(findModal().text()).toBe('Are you sure you want to delete this custom role?');
    });

    it('shows Delete role button', () => {
      expect(findModal().props('actionPrimary')).toEqual({
        text: 'Delete role',
        attributes: { variant: 'danger', loading: false },
      });
    });

    it('shows Cancel button', () => {
      expect(findModal().props('actionCancel')).toEqual({
        text: 'Cancel',
        attributes: { disabled: false },
      });
    });

    it.each(['ok', 'esc', 'cancel', 'backdrop', 'headerclose', null])(
      'allows modal to be closed for the "%s" trigger',
      (trigger) => {
        const event = { preventDefault: jest.fn(), trigger };
        findModal().vm.$emit('hide', event);

        expect(event.preventDefault).not.toHaveBeenCalled();
      },
    );

    it('emits close event when modal is closed', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });

  it.each`
    phrase     | role
    ${'shows'} | ${defaultRole}
    ${'hides'} | ${null}
  `('$phrase modal when role is $role', ({ role }) => {
    createComponent({ role });

    expect(findModal().props('visible')).toBe(Boolean(role));
  });

  describe('when Delete role button is clicked', () => {
    beforeEach(() => {
      createComponent();
      findModal().vm.$emit('primary', new Event('primary'));
    });

    it('runs delete mutation', () => {
      expect(defaultDeleteMutationHandler).toHaveBeenCalledTimes(1);
      expect(defaultDeleteMutationHandler).toHaveBeenCalledWith({
        input: { id: 'gid://gitlab/MemberRole/5' },
      });
    });

    it('changes Delete role button to loading', () => {
      expect(findModal().props('actionPrimary').attributes.loading).toBe(true);
    });

    it('changes Cancel button to disabled', () => {
      expect(findModal().props('actionCancel').attributes.disabled).toBe(true);
    });

    it.each`
      phrase                                     | trigger
      ${'Delete role button is clicked'}         | ${'ok'}
      ${'Cancel button is clicked'}              | ${'cancel'}
      ${'Esc key is pressed'}                    | ${'esc'}
      ${'modal backdrop is clicked'}             | ${'backdrop'}
      ${'X icon in the modal header is clicked'} | ${'headerclose'}
    `('prevents the modal from closing when the $phrase', ({ trigger }) => {
      const event = { preventDefault: jest.fn(), trigger };
      findModal().vm.$emit('hide', event);

      expect(event.preventDefault).toHaveBeenCalledTimes(1);
    });

    it('emits deleted event when deletion is finished', async () => {
      // Sanity check to make sure we don't prematurely emit the deleted event before the mutation is done.
      expect(wrapper.emitted('deleted')).toBeUndefined();

      await waitForPromises();

      expect(wrapper.emitted('deleted')).toHaveLength(1);
    });
  });

  describe('when the modal is closed', () => {
    beforeEach(() => {
      createComponent();
      findModal().vm.$emit('hidden');
    });

    it('emits close event', () => {
      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('re-enables Delete role button', () => {
      expect(findModal().props('actionPrimary').attributes.loading).toBe(false);
    });

    it('re-enables Cancel button', () => {
      expect(findModal().props('actionCancel').attributes.disabled).toBe(false);
    });
  });

  describe.each`
    phrase                                              | deleteMutationHandler                     | expectedText
    ${'backend mutation response has an error message'} | ${getDeleteMutationHandler('some error')} | ${'Failed to delete role. some error'}
    ${'role delete throws an exception'}                | ${jest.fn().mockRejectedValue()}          | ${'Failed to delete role.'}
  `('when $phrase', ({ deleteMutationHandler, expectedText }) => {
    beforeEach(() => {
      createComponent({ deleteMutationHandler });
      findModal().vm.$emit('primary', new Event('primary'));
      return waitForPromises();
    });

    it('shows an alert', () => {
      expect(findAlert().text()).toBe(expectedText);
      expect(findAlert().props()).toMatchObject({
        variant: 'danger',
        dismissible: false,
      });
    });

    it('shows modal as visible', () => {
      expect(findModal().props('visible')).toBe(true);
    });

    it('re-enables Delete role button', () => {
      expect(findModal().props('actionPrimary').attributes.loading).toBe(false);
    });

    it('re-enables Cancel button', () => {
      expect(findModal().props('actionCancel').attributes.disabled).toBe(false);
    });

    it('clears alert when modal is closed', async () => {
      findModal().vm.$emit('hidden');
      await nextTick();

      expect(findAlert().exists()).toBe(false);
    });
  });
});
