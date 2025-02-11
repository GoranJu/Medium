<script>
import emptyStateSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-epic-md.svg';
import { GlEmptyState, GlButton } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_LABEL } from '~/graphql_shared/constants';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import EmptyStateWithoutAnyIssues from '~/issues/list/components/empty_state_without_any_issues.vue';
import { WORK_ITEM_TYPE_ENUM_EPIC, WORK_ITEM_TYPE_ENUM_ISSUE } from '~/work_items/constants';
import WorkItemsListApp from '~/work_items/pages/work_items_list_app.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import EpicsListBulkEditSidebar from 'ee/epics_list/components/epics_list_bulk_edit_sidebar.vue';
import { isLabelsWidget } from '~/work_items/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import workItemBulkUpdateMutation from '~/work_items/graphql/work_item_bulk_update.mutation.graphql';
import workItemParent from '../graphql/list/work_item_parent.query.graphql';

export default {
  emptyStateSvg,
  WORK_ITEM_TYPE_ENUM_EPIC,
  components: {
    CreateWorkItemModal,
    EmptyStateWithAnyIssues,
    EmptyStateWithoutAnyIssues,
    GlEmptyState,
    GlButton,
    WorkItemsListApp,
    EpicsListBulkEditSidebar,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: [
    'hasEpicsFeature',
    'showNewIssueLink',
    'canBulkEditEpics',
    'groupIssuesPath',
    'workItemType',
    'fullPath',
    'isGroup',
  ],
  props: {
    withTabs: {
      type: Boolean,
      required: false,
      default: true,
    },
    newCommentTemplatePaths: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      workItemUpdateCount: 0,
      bulkEditInProgress: false,
      showBulkEditSidebar: false,
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    parentId: {
      query: workItemParent,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespace.id;
      },
    },
  },
  computed: {
    allowEpicBulkEditing() {
      return (
        this.hasEpicsFeature &&
        this.canBulkEditEpics &&
        this.workItemType === WORK_ITEM_TYPE_ENUM_EPIC &&
        this.glFeatures.bulkUpdateWorkItemsMutation
      );
    },
    workItemTypeName() {
      return this.workItemType === WORK_ITEM_TYPE_ENUM_EPIC
        ? WORK_ITEM_TYPE_ENUM_EPIC
        : WORK_ITEM_TYPE_ENUM_ISSUE;
    },
    isEpic() {
      return this.workItemType === WORK_ITEM_TYPE_ENUM_EPIC;
    },
  },
  methods: {
    incrementUpdateCount() {
      this.workItemUpdateCount += 1;
    },
    convertWorkItemsToIssuables(workItems) {
      return workItems.map((workItem) => ({
        labels: workItem.widgets.find(isLabelsWidget).labels,
        ...workItem,
      }));
    },
    buildInputFromBulkUpdateEvent(updateEvent) {
      return {
        parentId: this.parentId,
        ids: updateEvent.issuable_gids,
        labelsWidget: {
          addLabelIds: updateEvent.add_label_ids.map((id) =>
            convertToGraphQLId(TYPENAME_LABEL, id),
          ),
          removeLabelIds: updateEvent.remove_label_ids.map((id) =>
            convertToGraphQLId(TYPENAME_LABEL, id),
          ),
        },
      };
    },
    async handleWorkItemBulkEdit(updateEvent) {
      this.bulkEditInProgress = true;

      try {
        const input = this.buildInputFromBulkUpdateEvent(updateEvent);
        await this.$apollo.mutate({
          mutation: workItemBulkUpdateMutation,
          variables: {
            input,
          },
        });

        this.incrementUpdateCount();
      } catch (error) {
        createAlert({
          message: s__('Epics|Something went wrong while updating epics.'),
          captureError: true,
          error,
        });
      } finally {
        this.bulkEditInProgress = false;
        this.showBulkEditSidebar = false;
      }
    },
  },
};
</script>

<template>
  <work-items-list-app
    :show-bulk-edit-sidebar="showBulkEditSidebar"
    :ee-work-item-update-count="workItemUpdateCount"
    :with-tabs="withTabs"
    :new-comment-template-paths="newCommentTemplatePaths"
  >
    <template v-if="hasEpicsFeature && showNewIssueLink" #nav-actions>
      <div class="gl-flex gl-gap-3">
        <gl-button
          v-if="allowEpicBulkEditing"
          class="!gl-w-auto gl-grow"
          data-testid="bulk-edit-start-button"
          :disabled="showBulkEditSidebar"
          @click="showBulkEditSidebar = true"
          >{{ __('Bulk edit') }}</gl-button
        >
        <create-work-item-modal
          :is-group="isGroup"
          class="gl-grow"
          :work-item-type-name="workItemTypeName"
          :always-show-work-item-type-select="showNewIssueLink"
          @workItemCreated="incrementUpdateCount"
        />
      </div>
    </template>
    <template v-if="hasEpicsFeature" #list-empty-state="{ hasSearch, isOpenTab }">
      <empty-state-with-any-issues
        :has-search="hasSearch"
        :is-epic="isEpic"
        :is-open-tab="isOpenTab"
      >
        <template v-if="showNewIssueLink" #new-issue-button>
          <create-work-item-modal
            class="gl-grow"
            :is-group="isGroup"
            :work-item-type-name="workItemTypeName"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </empty-state-with-any-issues>
    </template>
    <template v-if="hasEpicsFeature && isEpic" #page-empty-state>
      <gl-empty-state
        :description="
          __('Track groups of issues that share a theme, across projects and milestones')
        "
        :svg-path="$options.emptyStateSvg"
        :title="
          __(
            'Epics let you manage your portfolio of projects more efficiently and with less effort',
          )
        "
      >
        <template v-if="showNewIssueLink" #actions>
          <create-work-item-modal
            class="gl-grow"
            :is-group="isGroup"
            :work-item-type-name="$options.WORK_ITEM_TYPE_ENUM_EPIC"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </gl-empty-state>
    </template>
    <template v-else #page-empty-state>
      <empty-state-without-any-issues>
        <template #new-issue-button>
          <create-work-item-modal
            :is-group="isGroup"
            :work-item-type-name="workItemTypeName"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </empty-state-without-any-issues>
    </template>
    <template v-if="allowEpicBulkEditing" #bulk-edit-actions="{ checkedIssuables }">
      <gl-button
        variant="confirm"
        type="submit"
        form="epics-list-bulk-edit"
        :disabled="checkedIssuables.length === 0 || bulkEditInProgress"
        :loading="bulkEditInProgress"
        >{{ __('Update selected') }}</gl-button
      >
      <gl-button class="gl-float-right" @click="showBulkEditSidebar = false">{{
        __('Cancel')
      }}</gl-button>
    </template>
    <template v-if="allowEpicBulkEditing" #sidebar-items="{ checkedIssuables }">
      <epics-list-bulk-edit-sidebar
        :checked-epics="convertWorkItemsToIssuables(checkedIssuables)"
        @bulk-update="handleWorkItemBulkEdit"
      />
    </template>
  </work-items-list-app>
</template>
