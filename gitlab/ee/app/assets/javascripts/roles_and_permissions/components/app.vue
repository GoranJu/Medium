<script>
import { GlSprintf, GlLink, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createAlert } from '~/alert';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import groupRolesQuery from '../graphql/group_roles.query.graphql';
import instanceRolesQuery from '../graphql/instance_roles.query.graphql';
import RolesTable from './roles_table.vue';
import DeleteRoleModal from './delete_role_modal.vue';
import RolesExport from './roles_export.vue';

export default {
  name: 'RolesApp',
  i18n: {
    title: s__('MemberRole|Roles and permissions'),
    description: s__(
      'MemberRole|Manage which actions users can take with %{linkStart}roles and permissions%{linkEnd}.',
    ),
    roleCount: s__(
      `MemberRole|%{rolesStart}Roles:%{rolesEnd} %{customCount} Custom %{defaultCount} Default`,
    ),
    newRoleText: s__('MemberRole|New role'),
    fetchRolesError: s__('MemberRole|Failed to fetch roles.'),
    roleDeletedText: s__('MemberRole|Role successfully deleted.'),
  },
  components: {
    GlSprintf,
    GlLink,
    GlButton,
    RolesTable,
    DeleteRoleModal,
    RolesExport,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagMixin()],
  props: {
    groupFullPath: {
      type: String,
      required: false,
      default: '',
    },
    newRolePath: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      rolesData: null,
      roleToDelete: null,
    };
  },
  apollo: {
    rolesData: {
      query() {
        return this.groupFullPath ? groupRolesQuery : instanceRolesQuery;
      },
      variables() {
        return this.groupFullPath ? { fullPath: this.groupFullPath } : {};
      },
      update(data) {
        return this.groupFullPath ? data.group : data;
      },
      error() {
        createAlert({ message: this.$options.i18n.fetchRolesError, dismissible: false });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.rolesData.loading;
    },
    defaultRoles() {
      return this.rolesData?.standardRoles.nodes || [];
    },
    customRoles() {
      return this.rolesData?.memberRoles.nodes || [];
    },
    roles() {
      return [...this.defaultRoles, ...this.customRoles];
    },
    canExportRoles() {
      // Check that the backend feature is enabled and that the current user can export members.
      return (
        this.glFeatures.membersPermissionsDetailedExport && this.glAbilities.exportGroupMemberships
      );
    },
  },
  methods: {
    processRoleDeletion() {
      this.roleToDelete = null;
      this.$toast.show(this.$options.i18n.roleDeletedText);
      this.$apollo.queries.rolesData.refetch();
    },
  },
  userPermissionsDocPath: helpPagePath('user/permissions'),
};
</script>

<template>
  <section>
    <h2 class="gl-mb-2">{{ $options.i18n.title }}</h2>

    <p class="gl-mb-5 gl-text-subtle">
      <gl-sprintf :message="$options.i18n.description">
        <template #link="{ content }">
          <gl-link :href="$options.userPermissionsDocPath" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>

    <div class="gl-mb-4 gl-flex gl-flex-wrap gl-items-center gl-justify-between gl-gap-3">
      <span data-testid="role-counts">
        <gl-sprintf :message="$options.i18n.roleCount">
          <template #roles="{ content }">
            <span class="gl-font-bold">{{ content }}</span>
          </template>
          <template #customCount>
            <span class="gl-font-bold">{{ customRoles.length }}</span>
          </template>
          <template #defaultCount>
            <span class="gl-ml-2 gl-font-bold">{{ defaultRoles.length }}</span>
          </template>
        </gl-sprintf>
      </span>

      <div class="gl-flex gl-flex-wrap gl-gap-4">
        <roles-export v-if="canExportRoles" />

        <gl-button v-if="newRolePath" :href="newRolePath" variant="confirm">
          {{ $options.i18n.newRoleText }}
        </gl-button>
      </div>
    </div>

    <roles-table :roles="roles" :busy="isLoading" @delete-role="roleToDelete = $event" />

    <delete-role-modal
      :role="roleToDelete"
      @deleted="processRoleDeletion"
      @close="roleToDelete = null"
    />
  </section>
</template>
