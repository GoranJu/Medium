<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { __ } from '~/locale';

export default {
  props: {
    branches: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    isAllBranches() {
      return !this.branches?.length;
    },
    branchName() {
      return this.isAllBranches
        ? __('All branches')
        : this.branches.map((branch) => branch.name).join(', ');
    },
  },
};
</script>

<template>
  <span :class="{ monospace: !isAllBranches }">{{ branchName }}</span>
</template>
