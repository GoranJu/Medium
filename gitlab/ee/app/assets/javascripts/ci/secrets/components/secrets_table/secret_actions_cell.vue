<script>
import { GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';

export default {
  name: 'SecretActionsCell',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  props: {
    detailsRoute: {
      type: Object,
      required: true,
    },
  },
};
</script>
<template>
  <gl-disclosure-dropdown
    icon="ellipsis_v"
    :toggle-text="s__('Secrets|Actions')"
    text-sr-only
    category="tertiary"
    no-caret
  >
    <gl-disclosure-dropdown-item>
      <template #list-item>
        <router-link
          data-testid="secret-details-link"
          :to="detailsRoute"
          class="gl-block gl-text-default hover:gl-text-default hover:gl-no-underline"
        >
          {{ s__('Secrets|Edit secret') }}
        </router-link>
      </template>
    </gl-disclosure-dropdown-item>
    <gl-disclosure-dropdown-item>
      <template #list-item>
        <span class="gl-text-danger">{{ s__('Secrets|Delete') }}</span>
      </template>
    </gl-disclosure-dropdown-item>
    <gl-disclosure-dropdown-item>
      <template #list-item>
        <span class="gl-text-danger">{{ s__('Secrets|Revoke') }}</span>
      </template>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown>
</template>
