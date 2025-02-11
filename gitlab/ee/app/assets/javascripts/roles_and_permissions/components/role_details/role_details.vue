<script>
import {
  GlSprintf,
  GlTabs,
  GlAlert,
  GlButton,
  GlTooltipDirective,
  GlLoadingIcon,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { BASE_ROLES_WITHOUT_MINIMAL_ACCESS } from '~/access_level/constants';
import { visitUrl } from '~/lib/utils/url_utility';
import { TYPENAME_MEMBER_ROLE } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import DeleteRoleModal from '../delete_role_modal.vue';
import memberRoleQuery from '../../graphql/role_details/member_role.query.graphql';
import DetailsTab from './details_tab.vue';

export default {
  components: {
    GlSprintf,
    GlTabs,
    DetailsTab,
    GlAlert,
    GlButton,
    GlLoadingIcon,
    DeleteRoleModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    roleId: {
      type: String,
      required: true,
    },
    listPagePath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      memberRole: null,
      roleToDelete: null,
    };
  },
  apollo: {
    memberRole: {
      query: memberRoleQuery,
      errorPolicy: 'none', // This is needed to stop the result() block from being called when there's an error.
      variables() {
        return { id: convertToGraphQLId(TYPENAME_MEMBER_ROLE, this.roleId) };
      },
      error() {
        this.memberRole = null;
      },
      skip() {
        return Boolean(this.standardRole);
      },
    },
  },
  computed: {
    standardRole() {
      return BASE_ROLES_WITHOUT_MINIMAL_ACCESS.find(
        ({ value }) => value === this.roleId.toUpperCase(),
      );
    },
    role() {
      return this.memberRole || this.standardRole;
    },
    headerDescription() {
      return this.memberRole
        ? s__('MemberRole|Custom role created on %{dateTime}')
        : s__('MemberRole|This role is available by default and cannot be changed.');
    },
    createdDate() {
      return localeDateFormat.asDate.format(this.role.createdAt);
    },
    deleteButtonTooltip() {
      // The button will be disabled if there are assigned members, so we want to show the tooltip immediately on hover
      // instead of the default 0.5-second delay.
      return this.hasAssignedUsers
        ? { title: s__('MemberRole|To delete custom role, remove role from all users.'), delay: 0 }
        : s__('MemberRole|Delete role');
    },
    hasAssignedUsers() {
      return this.role.usersCount > 0;
    },
  },
  methods: {
    navigateToListPage() {
      visitUrl(this.listPagePath);
    },
  },
};
</script>

<template>
  <gl-loading-icon v-if="$apollo.queries.memberRole.loading" size="md" class="gl-mt-5" />

  <gl-alert v-else-if="!role" variant="danger" class="gl-mt-5" :dismissible="false">
    {{ s__('MemberRole|Failed to fetch role.') }}
  </gl-alert>

  <div v-else data-testid="role-details">
    <header class="gl-mb-4 gl-mt-6 gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <h1 class="gl-m-0 gl-mr-auto">{{ role.name || role.text }}</h1>

      <div v-if="memberRole" class="gl-flex gl-items-center gl-gap-3">
        <gl-button
          v-gl-tooltip="s__('MemberRole|Edit role')"
          icon="pencil"
          :href="role.editPath"
          class="gl-ml-2"
          data-testid="edit-button"
        />
        <div v-gl-tooltip="deleteButtonTooltip" data-testid="delete-button">
          <gl-button
            icon="remove"
            category="secondary"
            variant="danger"
            :disabled="hasAssignedUsers"
            @click="roleToDelete = role"
          />
        </div>

        <delete-role-modal
          :role="roleToDelete"
          @deleted="navigateToListPage"
          @close="roleToDelete = null"
        />
      </div>
    </header>

    <p class="gl-w-full">
      <gl-sprintf :message="headerDescription">
        <template #dateTime>{{ createdDate }}</template>
      </gl-sprintf>
    </p>

    <gl-tabs>
      <details-tab :role="role" />
    </gl-tabs>
  </div>
</template>
