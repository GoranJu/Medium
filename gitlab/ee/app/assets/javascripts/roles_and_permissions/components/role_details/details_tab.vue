<script>
import { GlTab, GlButton, GlIcon, GlSprintf, GlSkeletonLoader } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createAlert } from '~/alert';
import memberRolePermissionsQuery from '../../graphql/member_role_permissions.query.graphql';
import { isCustomRole } from '../../utils';

export default {
  components: { GlTab, GlButton, GlIcon, GlSprintf, GlSkeletonLoader },
  props: {
    role: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      allPermissions: [],
    };
  },
  apollo: {
    allPermissions: {
      query: memberRolePermissionsQuery,
      variables: { includeDescription: false },
      update(data) {
        return data.memberRolePermissions.nodes.map((permission) => ({
          ...permission,
          checked: this.enabledPermissions.has(permission.value),
        }));
      },
      error() {
        createAlert({ message: s__('MemberRole|Could not fetch available permissions.') });
      },
      skip() {
        // Base roles don't show permissions, so don't fetch the available permissions.
        return !this.isCustomRole;
      },
    },
  },
  computed: {
    enabledPermissions() {
      return new Set(this.role.enabledPermissions.nodes.map(({ value }) => value));
    },
    isCustomRole() {
      return isCustomRole(this.role);
    },
    idLabel() {
      return this.isCustomRole ? s__('MemberRole|Role ID') : s__('MemberRole|Access level');
    },
    roleId() {
      // Custom roles should show the custom role ID. Base roles don't have an ID, so show the access level instead.
      return getIdFromGraphQLId(this.role.id) || this.role.accessLevel;
    },
    roleType() {
      return this.isCustomRole ? __('Custom') : s__('MemberRole|Default');
    },
  },
  userPermissionsDocsPath: helpPagePath('user/permissions'),
};
</script>
<template>
  <gl-tab :title="__('Details')">
    <h4 class="gl-mb-5">{{ __('General') }}</h4>
    <dl class="gl-mb-8">
      <dt data-testid="id-header">{{ idLabel }}</dt>
      <dd class="gl-mb-6 gl-mt-3 gl-text-subtle" data-testid="id-value">{{ roleId }}</dd>

      <dt data-testid="type-header">{{ s__('MemberRole|Role type') }}</dt>
      <dd class="gl-mb-6 gl-mt-3 gl-text-subtle" data-testid="type-value">{{ roleType }}</dd>

      <dt data-testid="description-header">{{ __('Description') }}</dt>
      <dd class="gl-mt-3 gl-leading-20 gl-text-subtle" data-testid="description-value">
        {{ role.description }}
      </dd>
    </dl>

    <h4>{{ __('Permissions') }}</h4>
    <dl>
      <dt v-if="isCustomRole" data-testid="base-role-header">{{ s__('MemberRole|Base role') }}</dt>
      <dd class="gl-mb-6 gl-mt-3 gl-flex gl-gap-x-5 gl-text-subtle">
        <span v-if="isCustomRole" data-testid="base-role-value">
          {{ role.baseAccessLevel.humanAccess }}
        </span>
        <gl-button
          :href="$options.userPermissionsDocsPath"
          icon="external-link"
          variant="link"
          target="_blank"
          data-testid="view-permissions-button"
        >
          {{ s__('MemberRole|View permissions') }}
        </gl-button>
      </dd>

      <template v-if="isCustomRole">
        <dt data-testid="custom-permissions-header">{{ s__('MemberRole|Custom permissions') }}</dt>
        <dd
          v-if="allPermissions.length"
          class="gl-mb-6 gl-mt-3 gl-text-subtle"
          data-testid="custom-permissions-value"
        >
          <gl-sprintf :message="s__('MemberRole|%{count} of %{total} permissions added')">
            <template #count>{{ enabledPermissions.size }}</template>
            <template #total>{{ allPermissions.length }}</template>
          </gl-sprintf>
        </dd>

        <div class="gl-flex gl-flex-col gl-gap-y-4" data-testid="custom-permissions-list">
          <gl-skeleton-loader v-if="$apollo.queries.allPermissions.loading" />
          <div
            v-for="permission in allPermissions"
            :key="permission.value"
            :data-testid="`permission-${permission.value}`"
            :class="{ 'gl-text-subtle': !permission.checked }"
          >
            <gl-icon v-if="permission.checked" name="check-sm" variant="success" />
            <gl-icon v-else name="merge-request-close-m" variant="disabled" />

            <span class="gl-ml-2">{{ permission.name }}</span>
          </div>
        </div>
      </template>
    </dl>
  </gl-tab>
</template>
