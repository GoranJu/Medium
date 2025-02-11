<script>
import {
  GlButton,
  GlEmptyState,
  GlLoadingIcon,
  GlSprintf,
  GlLink,
  GlTooltipDirective,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapGetters, mapState } from 'vuex';
import { getTimeago } from '~/lib/utils/datetime_utility';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { DEPENDENCY_LIST_TYPES } from '../store/constants';
import { NAMESPACE_GROUP, NAMESPACE_ORGANIZATION, NAMESPACE_PROJECT } from '../constants';
import { SORT_FIELD_SEVERITY } from '../store/modules/list/constants';
import DependenciesActions from './dependencies_actions.vue';
import SbomReportsErrorsAlert from './sbom_reports_errors_alert.vue';
import PaginatedDependenciesTable from './paginated_dependencies_table.vue';

export default {
  name: 'DependenciesApp',
  components: {
    DependenciesActions,
    GlButton,
    GlEmptyState,
    GlLoadingIcon,
    GlSprintf,
    GlLink,
    PaginatedDependenciesTable,
    SbomReportsErrorsAlert,
    HelpIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: [
    'hasDependencies',
    'emptyStateSvgPath',
    'documentationPath',
    'endpoint',
    'exportEndpoint',
    'pageInfo',
    'namespaceType',
    'latestSuccessfulScanPath',
    'scanFinishedAt',
  ],
  props: {
    sbomReportsErrors: {
      type: Array,
      required: true,
    },
  },
  computed: {
    ...mapState(['currentList', 'listTypes']),
    ...mapGetters(['isInitialized', 'totals']),
    ...mapState(DEPENDENCY_LIST_TYPES.all.namespace, ['pageInfo']),
    ...mapState({
      fetchingInProgress(state) {
        return state[this.currentList].fetchingInProgress;
      },
    }),
    exportButtonIcon() {
      return this.fetchingInProgress ? '' : 'export';
    },
    exportTooltip() {
      return this.isOrganizationNamespace
        ? s__('Dependencies|Export as CSV')
        : s__('Dependencies|Export as JSON');
    },
    currentListIndex: {
      get() {
        return this.listTypes.map(({ namespace }) => namespace).indexOf(this.currentList);
      },
      set(index) {
        const { namespace } = this.listTypes[index] || {};
        this.setCurrentList(namespace);
      },
    },
    showSbomReportsErrors() {
      return this.sbomReportsErrors.length > 0;
    },
    asyncExportEnabled() {
      return this.asyncExportEnabledForProject || this.asyncExportEnabledForGroup;
    },
    asyncExportEnabledForProject() {
      return (
        this.isProjectNamespace && this.glFeatures.asynchronousDependencyExportDeliveryForProjects
      );
    },
    asyncExportEnabledForGroup() {
      return this.isGroupNamespace && this.glFeatures.asynchronousDependencyExportDeliveryForGroups;
    },
    isProjectNamespace() {
      return this.namespaceType === NAMESPACE_PROJECT;
    },
    isGroupNamespace() {
      return this.namespaceType === NAMESPACE_GROUP;
    },
    isOrganizationNamespace() {
      return this.namespaceType === NAMESPACE_ORGANIZATION;
    },
    message() {
      return this.isProjectNamespace
        ? s__(
            'Dependencies|Software Bill of Materials (SBOM) based on the %{linkStart}latest successful%{linkEnd} scan',
          )
        : s__(
            'Dependencies|Software Bill of Materials (SBOM) based on the latest successful scan of each project.',
          );
    },
    generatedAtTimeAgo() {
      return this.scanFinishedAt ? getTimeago().format(this.scanFinishedAt) : '';
    },
  },
  created() {
    this.setDependenciesEndpoint(this.endpoint);
    this.setExportDependenciesEndpoint(this.exportEndpoint);
    this.setNamespaceType(this.namespaceType);
    this.setPageInfo(this.pageInfo);
    this.setSortField(SORT_FIELD_SEVERITY);
    this.setAsyncExport(this.asyncExportEnabled);
  },
  methods: {
    ...mapActions([
      'setDependenciesEndpoint',
      'setExportDependenciesEndpoint',
      'setNamespaceType',
      'setPageInfo',
      'setSortField',
      'setCurrentList',
      'setAsyncExport',
    ]),
    ...mapActions({
      fetchExport(dispatch) {
        dispatch(`${this.currentList}/fetchExport`);
      },
    }),
  },
  i18n: {
    emptyStateTitle: __('View dependency details for your project'),
    emptyStateDescription: __(
      'The dependency list details information about the components used within your project.',
    ),
    emptyStateLinkText: __('More Information'),
  },
};
</script>

<template>
  <gl-loading-icon v-if="!isInitialized" size="lg" class="mt-4" />

  <gl-empty-state
    v-else-if="!hasDependencies"
    :title="$options.i18n.emptyStateTitle"
    :svg-path="emptyStateSvgPath"
    :svg-height="null"
    data-testid="dependency-list-empty-state-description-content"
  >
    <template #description>
      {{ $options.i18n.emptyStateDescription }}
      <gl-link target="_blank" :href="documentationPath">
        {{ $options.i18n.emptyStateLinkText }}
      </gl-link>
    </template>
  </gl-empty-state>

  <section v-else>
    <sbom-reports-errors-alert
      v-if="showSbomReportsErrors"
      :errors="sbomReportsErrors"
      class="gl-my-5"
    />

    <header class="gl-my-5 gl-items-start md:gl-flex">
      <div class="gl-mr-auto">
        <h2 class="h4 gl-mb-2 gl-mt-0 gl-flex gl-items-center">
          {{ __('Dependencies') }}
          <gl-link
            class="gl-ml-3"
            target="_blank"
            :href="documentationPath"
            :aria-label="__('Dependencies help page link')"
          >
            <help-icon />
          </gl-link>
        </h2>
        <p class="gl-mb-0">
          <gl-sprintf :message="message">
            <template #link="{ content }">
              <gl-link
                v-if="latestSuccessfulScanPath"
                ref="scanLink"
                :href="latestSuccessfulScanPath"
                >{{ content }}</gl-link
              >
              <template v-else>{{ content }}</template>
            </template>
          </gl-sprintf>
          <span v-if="generatedAtTimeAgo" data-testid="time-ago-message">
            <span aria-hidden="true">&bull;</span>
            <span class="gl-text-subtle">{{ generatedAtTimeAgo }}</span>
          </span>
        </p>
      </div>
      <gl-button
        v-if="exportEndpoint"
        v-gl-tooltip.hover
        :title="exportTooltip"
        class="gl-mt-3 md:gl-mt-0"
        :icon="exportButtonIcon"
        data-testid="export"
        :loading="fetchingInProgress"
        @click="fetchExport"
      >
        {{ __('Export') }}
      </gl-button>
    </header>

    <dependencies-actions
      v-if="!isOrganizationNamespace"
      class="gl-mt-3"
      :namespace="currentList"
    />

    <article>
      <paginated-dependencies-table :namespace="currentList" />
    </article>
  </section>
</template>
