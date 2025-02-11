<script>
import { GlIcon } from '@gitlab/ui';
import IssueCardTimeInfo from '~/issues/list/components/issue_card_time_info.vue';
import IssueHealthStatus from 'ee/related_items_tree/components/issue_health_status.vue';
import { isHealthStatusWidget, isWeightWidget } from '~/work_items/utils';
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';

export default {
  components: {
    IssueCardTimeInfo,
    IssueHealthStatus,
    WorkItemAttribute,
    GlIcon,
  },
  inject: ['hasIssuableHealthStatusFeature', 'hasIssueWeightsFeature'],
  props: {
    issue: {
      type: Object,
      required: true,
    },
    isWorkItemList: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    healthStatus() {
      return (
        this.issue.healthStatus || this.issue.widgets?.find(isHealthStatusWidget)?.healthStatus
      );
    },
    showHealthStatus() {
      return this.hasIssuableHealthStatusFeature && this.healthStatus && !this.isWorkItemList;
    },
    weight() {
      return this.issue.weight || this.issue.widgets?.find(isWeightWidget)?.weight;
    },
    showWeight() {
      return this.hasIssueWeightsFeature && this.weight != null;
    },
  },
};
</script>

<template>
  <issue-card-time-info :issue="issue">
    <work-item-attribute
      v-if="showWeight"
      anchor-id="issuable-weight-content"
      :title="`${weight}`"
      title-component-class="issuable-weight gl-mr-3"
      :tooltip-text="__('Weight')"
      tooltip-placement="top"
    >
      <template #icon>
        <gl-icon name="weight" :size="12" />
      </template>
    </work-item-attribute>
    <issue-health-status v-if="showHealthStatus" :health-status="healthStatus" />
  </issue-card-time-info>
</template>
