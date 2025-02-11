<script>
import { GlTable, GlBadge, GlLoadingIcon, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isCustomRole } from '../utils';
import RoleActions from './role_actions.vue';

export const TABLE_FIELDS = [
  { key: 'name', label: s__('MemberRole|Name') },
  { key: 'description', label: s__('MemberRole|Description') },
  {
    key: 'usersCount',
    label: s__('MemberRole|Direct users assigned'),
    thClass: 'gl-w-12 gl-whitespace-nowrap',
    tdClass: 'gl-text-right',
  },
  {
    key: 'actions',
    label: s__('MemberRole|Actions'),
    thClass: 'gl-w-12',
    tdClass: 'gl-text-right !gl-p-3',
  },
];

export default {
  components: { GlTable, GlBadge, GlLoadingIcon, GlLink, RoleActions },
  props: {
    roles: {
      type: Array,
      required: true,
    },
    busy: {
      type: Boolean,
      required: true,
    },
  },
  methods: { isCustomRole },
  TABLE_FIELDS,
};
</script>

<template>
  <gl-table :fields="$options.TABLE_FIELDS" :items="roles" :busy="busy" stacked="md">
    <template #table-busy>
      <gl-loading-icon size="md" />
    </template>

    <template #cell(name)="{ item }">
      <div class="gl-items-center gl-whitespace-nowrap md:gl-flex">
        <gl-link :href="item.detailsPath">{{ item.name }}</gl-link>
        <gl-badge v-if="isCustomRole(item)" class="gl-ml-3">
          {{ s__('MemberRole|Custom role') }}
        </gl-badge>
      </div>
    </template>

    <template #cell(description)="{ item: { description } }">
      <template v-if="description">{{ description }}</template>
      <span v-else class="gl-text-subtle">{{ s__('MemberRole|No description') }}</span>
    </template>

    <template #cell(actions)="{ item }">
      <role-actions :role="item" @delete="$emit('delete-role', item)" />
    </template>
  </gl-table>
</template>
