<script>
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { fetchPolicies } from '~/lib/graphql';
import { s__ } from '~/locale';

import {
  GRAPHQL_PAGE_SIZE,
  FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK,
} from 'ee/compliance_dashboard/constants';
import {
  mapFiltersToUrlParams,
  mapQueryToFilters,
  checkFilterForChange,
} from 'ee/compliance_dashboard/utils';
import complianceFrameworksGroupProjects from '../../graphql/compliance_frameworks_group_projects.query.graphql';
import { mapProjects } from '../../graphql/mappers';
import Pagination from '../shared/pagination.vue';
import ProjectsTable from './projects_table.vue';
import Filters from './filters.vue';

export default {
  name: 'ComplianceFrameworkProjectsReport',
  components: {
    Filters,
    GlAlert,
    Pagination,
    ProjectsTable,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      hasQueryError: false,
      projects: {
        list: [],
        pageInfo: {},
      },
      shouldShowUpdatePopover: false,
    };
  },
  apollo: {
    projects: {
      query: complianceFrameworksGroupProjects,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      // See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/118580#note_1366339919 for explanation
      // why we need nextFetchPolicy
      nextFetchPolicy: fetchPolicies.CACHE_FIRST,
      variables() {
        return {
          groupPath: this.groupPath,
          ...this.paginationCursors,
          ...this.filterParams,
        };
      },
      update(data) {
        const { nodes, pageInfo } = data?.group?.projects || {};
        return {
          list: mapProjects(nodes),
          pageInfo,
        };
      },
      error(e) {
        Sentry.captureException(e);
        this.hasQueryError = true;
      },
    },
  },
  computed: {
    isLoading() {
      return Boolean(this.$apollo.queries.projects.loading);
    },
    showPagination() {
      const { hasPreviousPage, hasNextPage } = this.projects.pageInfo || {};
      return hasPreviousPage || hasNextPage;
    },
    paginationCursors() {
      const { before, after } = this.$route.query;

      if (before) {
        return {
          before,
          last: this.perPage,
        };
      }

      return {
        after,
        first: this.perPage,
      };
    },
    filterParams() {
      const { project, group, ...queryParams } = this.$route.query;
      const filters = { frameworks: [], frameworksNot: [] };
      const frameworks = queryParams['framework[]'];
      const notFrameworks = queryParams['not[framework][]'];

      const getFrameworkParams = (params, presenceType) => {
        const frameworksArray = Array.isArray(params) ? params : [params];
        const filteredFrameworks = frameworksArray.filter((f) => {
          if (f === FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK.id) {
            filters.presenceFilter = presenceType;
            return false;
          }
          return true;
        });
        return filteredFrameworks;
      };

      if (frameworks) {
        filters.frameworks = getFrameworkParams(frameworks, 'NONE');
      }

      if (notFrameworks) {
        filters.frameworksNot = getFrameworkParams(notFrameworks, 'ANY');
      }

      if (project) {
        filters.project = project;
      }

      if (group) {
        filters.groupPath = group;
      }

      return filters;
    },
    filters() {
      return mapQueryToFilters(this.$route.query);
    },
    perPage() {
      return parseInt(this.$route.query.perPage || GRAPHQL_PAGE_SIZE, 10);
    },
    hasFilters() {
      return this.filters.length !== 0;
    },
  },
  methods: {
    loadPrevPage(previousCursor) {
      this.$router.push({
        query: {
          ...this.$route.query,
          before: previousCursor,
          after: undefined,
        },
      });
    },
    loadNextPage(nextCursor) {
      this.$router.push({
        query: {
          ...this.$route.query,
          before: undefined,
          after: nextCursor,
        },
      });
    },
    onPageSizeChange(perPage) {
      this.$router.push({
        query: {
          ...this.$route.query,
          before: undefined,
          after: undefined,
          perPage,
        },
      });
    },
    onFiltersChanged(filters) {
      this.shouldShowUpdatePopover = false;
      const newFilters = mapFiltersToUrlParams(filters);
      if (checkFilterForChange({ currentFilters: this.$route.query, newFilters })) {
        this.$router.push({
          query: {
            before: undefined,
            after: undefined,
            ...newFilters,
          },
        });
      } else {
        this.$apollo.queries.projects.refetch();
      }
    },
    showUpdatePopoverIfNeeded() {
      if (this.filters.length) {
        this.shouldShowUpdatePopover = true;
      }
    },
  },
  i18n: {
    queryError: s__(
      'ComplianceReport|Unable to load the compliance framework projects report. Refresh the page and try again.',
    ),
  },
};
</script>

<template>
  <section>
    <filters
      :value="filters"
      :group-path="groupPath"
      :error="hasQueryError"
      :show-update-popover="shouldShowUpdatePopover"
      @update-popover-hidden="shouldShowUpdatePopover = false"
      @keyup.enter="onFiltersChanged"
      @submit="onFiltersChanged"
    />

    <gl-alert
      v-if="hasQueryError"
      variant="danger"
      class="gl-my-3"
      :dismissible="false"
      data-test-id="query-error-alert"
    >
      {{ $options.i18n.queryError }}
    </gl-alert>

    <projects-table
      v-else
      :is-loading="isLoading"
      :projects="projects.list"
      :root-ancestor="rootAncestor"
      :group-path="groupPath"
      :has-filters="hasFilters"
      @updated="showUpdatePopoverIfNeeded"
    />

    <pagination
      v-if="showPagination"
      :is-loading="isLoading"
      :page-info="projects.pageInfo"
      :per-page="perPage"
      @prev="loadPrevPage"
      @next="loadNextPage"
      @page-size-change="onPageSizeChange"
    />
  </section>
</template>
