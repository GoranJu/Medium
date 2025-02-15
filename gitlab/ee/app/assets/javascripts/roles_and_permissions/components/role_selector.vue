<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import { initialSelectedRole, roleDropdownItems } from 'ee/members/utils';

export default {
  i18n: {
    placeholder: __('Select a role'),
  },
  components: {
    GlCollapsibleListbox,
  },
  inject: {
    standardRoles: {
      type: Object,
      required: true,
    },
    currentStandardRole: {
      type: Number,
      required: false,
      default: null,
    },
    customRoles: {
      type: Array,
      required: false,
      default: () => [],
    },
    currentCustomRoleId: {
      type: Number,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      selectedRole: null,
      accessLevelOptions: roleDropdownItems({
        validRoles: this.standardRoles,
        customRoles: this.customRoles,
      }),
    };
  },
  computed: {
    selectedItem() {
      return this.accessLevelOptions.flatten.find(({ value }) => value === this.selectedRole);
    },
    toggleText() {
      return this.selectedRole ? this.selectedItem.text : this.$options.i18n.placeholder;
    },
  },
  watch: {
    accessLevelOptions: {
      immediate: true,
      handler(options) {
        const accessLevel = {
          integerValue: this.currentStandardRole,
          memberRoleId: this.currentCustomRoleId,
        };
        this.selectedRole = initialSelectedRole(options.flatten, { accessLevel })?.value;
      },
    },
  },
  methods: {
    onSelect() {
      const { accessLevel, memberRoleId } = this.selectedItem;

      this.$emit('onSelect', {
        selectedStandardRoleValue: accessLevel,
        selectedCustomRoleValue: memberRoleId,
      });
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    v-model="selectedRole"
    block
    :items="accessLevelOptions.formatted"
    :toggle-text="toggleText"
    @select="onSelect"
  />
</template>
