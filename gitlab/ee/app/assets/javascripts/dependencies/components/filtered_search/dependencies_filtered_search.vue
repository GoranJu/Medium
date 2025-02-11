<script>
import { GlFilteredSearch } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { s__ } from '~/locale';

export default {
  components: {
    GlFilteredSearch,
  },
  props: {
    filteredSearchId: {
      type: String,
      required: true,
    },
    tokens: {
      type: Array,
      required: true,
    },
    viewOnly: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    ...mapState(['currentList']),
  },
  methods: {
    ...mapActions('allDependencies', ['setSearchFilterParameters', 'fetchDependencies']),
  },
  i18n: {
    searchInputPlaceholder: s__('Dependencies|Search or filter dependencies...'),
  },
};
</script>

<template>
  <gl-filtered-search
    :id="filteredSearchId"
    :placeholder="$options.i18n.searchInputPlaceholder"
    :available-tokens="tokens"
    terms-as-tokens
    :view-only="viewOnly"
    @input="setSearchFilterParameters"
    @submit="fetchDependencies({ page: 1 })"
  />
</template>
