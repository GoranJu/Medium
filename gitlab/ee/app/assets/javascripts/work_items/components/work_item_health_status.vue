<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import IssueHealthStatus from 'ee/related_items_tree/components/issue_health_status.vue';
import {
  HEALTH_STATUS_I18N_HEALTH_STATUS,
  HEALTH_STATUS_I18N_NO_STATUS,
  HEALTH_STATUS_I18N_NONE,
  HEALTH_STATUS_I18N_SELECT_HEALTH_STATUS,
  healthStatusDropdownOptions,
} from 'ee/sidebar/constants';
import {
  I18N_WORK_ITEM_ERROR_UPDATING,
  sprintfWorkItem,
  TRACKING_CATEGORY_SHOW,
  WIDGET_TYPE_HEALTH_STATUS,
  i18n,
} from '~/work_items/constants';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import updateNewWorkItemMutation from '~/work_items/graphql/update_new_work_item.mutation.graphql';
import { newWorkItemId, newWorkItemFullPath } from '~/work_items/utils';
import { findWidget } from '~/issues/list/utils';
import Tracking from '~/tracking';

export default {
  HEALTH_STATUS_I18N_HEALTH_STATUS,
  HEALTH_STATUS_I18N_NO_STATUS,
  HEALTH_STATUS_I18N_NONE,
  HEALTH_STATUS_I18N_SELECT_HEALTH_STATUS,
  healthStatusDropdownOptions,
  components: {
    IssueHealthStatus,
    WorkItemSidebarDropdownWidget,
  },
  mixins: [Tracking.mixin()],
  inject: ['hasIssuableHealthStatusFeature'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      updateInProgress: false,
    };
  },
  computed: {
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_health_status',
        property: `type_${this.workItemType}`,
      };
    },
    dropdownItems() {
      const emptyItem = {
        text: this.$options.HEALTH_STATUS_I18N_NO_STATUS,
        value: null,
      };
      return [emptyItem, ...healthStatusDropdownOptions];
    },
    selectedHealthStatus() {
      return this.healthStatus || null;
    },
    healthStatus() {
      return findWidget(WIDGET_TYPE_HEALTH_STATUS, this.workItem)?.healthStatus;
    },
    createFlow() {
      return this.workItemId === newWorkItemId(this.workItemType);
    },
    workItemFullPath() {
      return this.createFlow
        ? newWorkItemFullPath(this.fullPath, this.workItemType)
        : this.fullPath;
    },
    canUpdate() {
      return this.workItem?.userPermissions?.updateWorkItem;
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    workItem: {
      query: workItemByIidQuery,
      variables() {
        return {
          fullPath: this.workItemFullPath,
          iid: this.workItemIid,
        };
      },
      update(data) {
        return data.workspace?.workItem || {};
      },
      skip() {
        return !this.workItemIid;
      },
      error() {
        this.$emit('error', i18n.fetchError);
      },
    },
  },
  methods: {
    updateHealthStatus(healthStatus) {
      if (!this.canUpdate) {
        return;
      }

      this.track('updated_health_status');

      this.updateInProgress = true;

      if (this.createFlow) {
        this.$apollo.mutate({
          mutation: updateNewWorkItemMutation,
          variables: {
            input: {
              fullPath: this.fullPath,
              healthStatus,
              workItemType: this.workItemType,
            },
          },
        });
        this.updateInProgress = false;
        return;
      }

      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              healthStatusWidget: {
                healthStatus,
              },
            },
          },
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('\n'));
          }
        })
        .catch((error) => {
          const msg = sprintfWorkItem(I18N_WORK_ITEM_ERROR_UPDATING, this.workItemType);
          this.$emit('error', msg);
          Sentry.captureException(error);
        })
        .finally(() => {
          this.updateInProgress = false;
        });
    },
  },
};
</script>

<template>
  <div v-if="hasIssuableHealthStatusFeature">
    <work-item-sidebar-dropdown-widget
      :dropdown-label="$options.HEALTH_STATUS_I18N_HEALTH_STATUS"
      :can-update="canUpdate"
      dropdown-name="health-status"
      :list-items="$options.healthStatusDropdownOptions"
      :item-value="selectedHealthStatus"
      :header-text="$options.HEALTH_STATUS_I18N_SELECT_HEALTH_STATUS"
      :update-in-progress="updateInProgress"
      :reset-button-label="__('Clear')"
      :searchable="false"
      data-testid="work-item-health-status"
      @updateValue="updateHealthStatus"
    >
      <template #readonly>
        <issue-health-status
          v-if="selectedHealthStatus"
          data-testid="work-item-health-status-value"
          display-as-text
          disable-tooltip
          :health-status="selectedHealthStatus"
        />
      </template>
    </work-item-sidebar-dropdown-widget>
  </div>
</template>
