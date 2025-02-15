<script>
import { GlFilteredSearchSuggestion, GlFilteredSearchToken, GlLoadingIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import getComplianceFrameworkQuery from 'ee/graphql_shared/queries/get_compliance_framework.query.graphql';
import { FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK } from '../../../constants';

export default {
  components: {
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    complianceFrameworks: {
      query: getComplianceFrameworkQuery,
      variables() {
        return {
          fullPath: this.config.groupPath,
        };
      },
      update(data) {
        return data.namespace?.complianceFrameworks?.nodes || [];
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isLoading() {
      return Boolean(this.$apollo.queries.complianceFrameworks.loading);
    },
    filteredFrameworks() {
      const searchTerm = this.value?.data || '';

      if (!searchTerm && this.complianceFrameworks) {
        return [FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK, ...this.complianceFrameworks];
      }

      const searchTermLower = searchTerm.toLowerCase();
      return this.complianceFrameworks?.filter((framework) => {
        return (
          framework.name.toLowerCase().includes(searchTermLower) ||
          framework.description?.toLowerCase().includes(searchTermLower)
        );
      });
    },
  },
  methods: {
    frameworkName(frameworkId) {
      if (frameworkId === FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK.id)
        return FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK.name;

      if (this.$apollo.queries.complianceFrameworks.loading) {
        return frameworkId;
      }

      const framework = this.complianceFrameworks.find(
        (complianceFramework) => complianceFramework.id === frameworkId,
      );
      return framework ? framework.name : frameworkId;
    },
  },
};
</script>

<template>
  <gl-filtered-search-token :config="config" v-bind="{ ...$props, ...$attrs }" v-on="$listeners">
    <template #view="{ inputValue }">
      {{ frameworkName(inputValue) }}
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoading" size="sm" />
      <template v-else>
        <gl-filtered-search-suggestion
          v-for="framework in filteredFrameworks"
          :key="framework.id"
          :value="framework.id"
        >
          {{ framework.name }}
        </gl-filtered-search-suggestion>
      </template>
    </template>
  </gl-filtered-search-token>
</template>
