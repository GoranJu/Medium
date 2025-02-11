<script>
import { GlModal, GlAlert } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import deleteMemberRoleMutation from 'ee/roles_and_permissions/graphql/delete_member_role.mutation.graphql';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_MEMBER_ROLE } from '~/graphql_shared/constants';

export default {
  components: { GlModal, GlAlert },
  props: {
    role: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      isDeletingRole: false,
      errorMessage: null,
    };
  },
  computed: {
    primaryActionProps() {
      return {
        text: s__('MemberRole|Delete role'),
        attributes: { variant: 'danger', loading: this.isDeletingRole },
      };
    },
    cancelActionProps() {
      return {
        text: __('Cancel'),
        attributes: { disabled: this.isDeletingRole },
      };
    },
  },
  methods: {
    checkModalClose(e) {
      // If the modal is trying to close due to user interaction but we're still deleting the role, don't close it.
      if (e.trigger && this.isDeletingRole) {
        e.preventDefault();
      }
    },
    emitClose() {
      this.$emit('close');
      this.isDeletingRole = false;
      this.errorMessage = null;
    },
    async deleteRole() {
      try {
        this.isDeletingRole = true;
        this.errorMessage = null;

        const { data } = await this.$apollo.mutate({
          mutation: deleteMemberRoleMutation,
          variables: { input: { id: convertToGraphQLId(TYPENAME_MEMBER_ROLE, this.role.id) } },
        });

        const error = data.memberRoleDelete.errors[0];

        if (error) {
          this.errorMessage = sprintf(s__('MemberRole|Failed to delete role. %{error}'), { error });
          this.isDeletingRole = false;
        } else {
          this.$emit('deleted');
        }
      } catch (e) {
        this.errorMessage = s__('MemberRole|Failed to delete role.');
        this.isDeletingRole = false;
      }
    },
  },
};
</script>

<template>
  <gl-modal
    modal-id="delete-role-modal"
    :visible="Boolean(role)"
    :title="s__('MemberRole|Delete custom role?')"
    :action-primary="primaryActionProps"
    :action-cancel="cancelActionProps"
    no-focus-on-show
    size="sm"
    @primary.prevent="deleteRole"
    @hide="checkModalClose"
    @hidden="emitClose"
  >
    {{ s__('MemberRole|Are you sure you want to delete this custom role?') }}

    <gl-alert v-if="errorMessage" variant="danger" :dismissible="false" class="gl-mt-4">
      {{ errorMessage }}
    </gl-alert>
  </gl-modal>
</template>
