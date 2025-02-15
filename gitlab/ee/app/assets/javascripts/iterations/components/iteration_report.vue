<script>
import { GlAlert, GlDisclosureDropdown, GlEmptyState, GlLoadingIcon, GlModal } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import BurnCharts from 'ee/burndown_chart/components/burn_charts.vue';
import { TYPENAME_ITERATION } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { WORKSPACE_GROUP } from '~/issues/constants';
import { s__, __ } from '~/locale';
import deleteIteration from '../queries/destroy_iteration.mutation.graphql';
import query from '../queries/iteration.query.graphql';
import { getIterationPeriod } from '../utils';
import IterationReportTabs from './iteration_report_tabs.vue';
import TimeboxStatusBadge from './timebox_status_badge.vue';
import IterationTitle from './iteration_title.vue';

export default {
  components: {
    BurnCharts,
    GlAlert,
    GlDisclosureDropdown,
    GlEmptyState,
    GlLoadingIcon,
    GlModal,
    IterationReportTabs,
    TimeboxStatusBadge,
    IterationTitle,
  },
  directives: {
    SafeHtml,
  },
  i18n: {
    editIterationLabel: __('Edit'),
    deleteIterationLabel: __('Delete'),
    iterationActionsDropdownLabel: __('Actions'),
  },
  apollo: {
    iteration: {
      query,
      variables() {
        return {
          fullPath: this.fullPath,
          id: convertToGraphQLId(TYPENAME_ITERATION, this.iterationId),
          isGroup: this.namespaceType === WORKSPACE_GROUP,
        };
      },
      update(data) {
        return data[this.namespaceType]?.iterations?.nodes[0] || {};
      },
      error(err) {
        this.error = s__('Iterations|Unable to find iteration.');
        // eslint-disable-next-line no-console
        console.error(err.message);
      },
    },
  },
  inject: [
    'fullPath',
    'hasScopedLabelsFeature',
    'canEditIteration',
    'namespaceType',
    'noIssuesSvgPath',
    'labelsFetchPath',
  ],
  modal: {
    actionPrimary: {
      text: __('Delete'),
      attributes: {
        variant: 'danger',
      },
    },
    actionCancel: {
      text: __('Cancel'),
      attributes: {
        variant: 'default',
      },
    },
  },
  data() {
    return {
      error: '',
      iteration: {},
      total: 0,
    };
  },
  computed: {
    canEdit() {
      return this.canEditIteration && this.namespaceType === WORKSPACE_GROUP;
    },
    loading() {
      return this.$apollo.queries.iteration.loading;
    },
    iterationId() {
      return this.$router.currentRoute.params.iterationId;
    },
    showEmptyState() {
      return !this.loading && this.iteration && !this.iteration.startDate;
    },
    editPage() {
      return {
        name: 'editIteration',
      };
    },
    editRoute() {
      return this.$router.resolve({ name: 'editIteration' }).href;
    },
    iterationPeriod() {
      return getIterationPeriod(this.iteration);
    },
    showDelete() {
      // We only support deleting iterations for manual cadences.
      return !this.iteration.iterationCadence.automatic;
    },
    dropdownItems() {
      const items = [
        {
          text: this.$options.i18n.editIterationLabel,
          href: this.editRoute,
        },
      ];
      if (this.showDelete) {
        items.push({
          text: this.$options.i18n.deleteIterationLabel,
          action: () => this.showModal(),
        });
      }
      return items;
    },
  },
  methods: {
    showModal() {
      this.$refs.modal.show();
    },
    focusMenu() {
      this.$refs.menu.$el.focus();
    },
    deleteIteration() {
      this.$apollo
        .mutate({
          mutation: deleteIteration,
          variables: {
            id: this.iteration.id,
          },
        })
        .then(({ data: { iterationDelete } }) => {
          if (iterationDelete.errors?.length) {
            throw iterationDelete.errors[0];
          }

          this.$router.push('/');
          this.$toast.show(s__('Iterations|The iteration has been deleted.'));
        })
        .catch((err) => {
          this.error = err;
        });
    },
    updateTotal(value) {
      this.total = value;
    },
  },
  safeHtmlConfig: { ADD_TAGS: ['gl-emoji'] },
};
</script>

<template>
  <div>
    <gl-alert v-if="error" variant="danger" @dismiss="error = ''">
      {{ error }}
    </gl-alert>
    <gl-loading-icon v-else-if="loading" class="gl-py-5" size="lg" />
    <gl-empty-state
      v-else-if="showEmptyState"
      :title="__('Could not find iteration')"
      :compact="false"
    />
    <template v-else>
      <div
        ref="topbar"
        class="gl-flex gl-items-center gl-justify-items-center gl-border-1 gl-border-default gl-py-3 gl-border-b-solid"
      >
        <timebox-status-badge :state="iteration.state" />
        <span class="gl-ml-4">{{ iterationPeriod }}</span>
        <gl-disclosure-dropdown
          v-if="canEdit"
          ref="menu"
          data-testid="actions-dropdown"
          :items="dropdownItems"
          icon="ellipsis_v"
          :toggle-text="$options.i18n.iterationActionsDropdownLabel"
          text-sr-only
          category="tertiary"
          class="gl-ml-auto"
          right
          no-caret
        />
        <gl-modal
          ref="modal"
          :modal-id="`${iteration.id}-delete-modal`"
          :title="s__('Iterations|Delete iteration?')"
          :action-primary="$options.modal.actionPrimary"
          :action-cancel="$options.modal.actionCancel"
          @hidden="focusMenu"
          @primary="deleteIteration"
        >
          {{
            s__(
              'Iterations|This will remove the iteration from any issues that are assigned to it.',
            )
          }}
        </gl-modal>
      </div>
      <div ref="heading">
        <h3 class="page-title gl-mb-1" data-testid="">{{ iterationPeriod }}</h3>
        <iteration-title v-if="iteration.title" :title="iteration.title" class="gl-text-subtle" />
      </div>
      <div
        ref="description"
        v-safe-html:[$options.safeHtmlConfig]="iteration.descriptionHtml"
        class="description md gl-mb-5"
      ></div>
      <burn-charts
        :start-date="iteration.startDate"
        :due-date="iteration.dueDate"
        :iteration-id="iteration.id"
        :iteration-state="iteration.state"
        :full-path="fullPath"
        :namespace-type="namespaceType"
        @updateTotal="updateTotal"
      />
      <iteration-report-tabs
        :full-path="fullPath"
        :has-scoped-labels-feature="hasScopedLabelsFeature"
        :iteration-id="iteration.id"
        :labels-fetch-path="labelsFetchPath"
        :namespace-type="namespaceType"
        :svg-path="noIssuesSvgPath"
        :total-iteration-issue-count="total"
      />
    </template>
  </div>
</template>
