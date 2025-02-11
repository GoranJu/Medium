<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__, sprintf } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import WorkItemChangeTypeModal from '~/work_items/components/work_item_change_type_modal.vue';
import promoteToEpicMutation from '~/issues/show/queries/promote_to_epic.mutation.graphql';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import {
  WORK_ITEM_TYPE_VALUE_EPIC,
  WIDGET_TYPE_WEIGHT,
  WORK_ITEM_TYPE_ENUM_EPIC,
  WORK_ITEM_TYPE_VALUE_ISSUE,
  WIDGET_TYPE_ASSIGNEES,
} from '~/work_items/constants';

export default {
  components: {
    WorkItemChangeTypeModal,
  },
  props: {
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: false,
      default: '',
    },
    workItemType: {
      type: String,
      required: false,
      default: null,
    },
    fullPath: {
      type: String,
      required: true,
    },
    hasChildren: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasParent: {
      type: Boolean,
      required: false,
      default: false,
    },
    widgets: {
      type: Array,
      required: false,
      default: () => [],
    },
    allowedChildTypes: {
      type: Array,
      required: false,
      default: () => [],
    },
    namespaceFullName: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      workItemTypes: [],
    };
  },
  apollo: {
    workItemTypes: {
      query: namespaceWorkItemTypesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.workspace?.workItemTypes?.nodes || [];
      },
      error(e) {
        this.throwError(e);
      },
    },
  },
  computed: {
    supportedConversionTypes() {
      return (
        this.workItemTypes?.find((type) => type.name === this.workItemType)
          ?.supportedConversionTypes || []
      );
    },
    allowedWorkItems() {
      const isEpicSupportedType =
        this.supportedConversionTypes.findIndex(
          ({ name }) => name === WORK_ITEM_TYPE_VALUE_EPIC,
        ) !== -1;

      if (this.workItemType === WORK_ITEM_TYPE_VALUE_ISSUE && isEpicSupportedType) {
        return [
          {
            text: __('Epic (Promote to group)'),
            value: WORK_ITEM_TYPE_ENUM_EPIC,
          },
        ];
      }
      return [];
    },
    epicFieldNote() {
      return sprintf(s__('WorkItem|Epic will be moved to parent group %{groupName}.'), {
        groupName: this.getParentGroupName(),
      });
    },
  },
  methods: {
    async promoteToEpic() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: promoteToEpicMutation,
          variables: {
            input: {
              iid: String(this.workItemIid),
              projectPath: this.fullPath,
            },
          },
        });

        if (data?.promoteToEpic?.errors?.length > 0) {
          this.$emit('error', data.promoteToEpic.errors[0]);
          return;
        }

        this.$toast.show(s__('WorkItem|Type changed.'));

        visitUrl(data.promoteToEpic.epic.webPath);
      } catch (error) {
        this.$emit('error', error.message);
        Sentry.captureException(error);
      }
    },
    show() {
      this.$refs.workItemsChangeTypeModal.show();
    },
    getEpicWidgetDefinitions({ workItemTypes }) {
      const epicWidgets = workItemTypes.find(
        (widget) => widget.name === WORK_ITEM_TYPE_VALUE_EPIC,
      )?.widgetDefinitions;
      const updatedWidgetDefinitions = epicWidgets.filter((widget) => {
        if (widget.type === WIDGET_TYPE_WEIGHT) {
          return widget.editable === true;
        }
        return true;
      });
      // The workItemTypes query is not fetching assignees widget, so we need to add it manually in frontend
      // Need to fix this in the backend
      updatedWidgetDefinitions.push({
        type: WIDGET_TYPE_ASSIGNEES,
        __typename: 'WorkItemWidgetDefinitionAssignees',
      });

      return updatedWidgetDefinitions;
    },
    getParentGroupName() {
      const parts = this.namespaceFullName.split('/');
      // Gets the second-to-last item in the reference path
      return parts.length > 1 ? parts[parts.length - 2].trim() : '';
    },
  },
};
</script>
<template>
  <work-item-change-type-modal
    ref="workItemsChangeTypeModal"
    :work-item-id="workItemId"
    :work-item-iid="workItemIid"
    :work-item-type="workItemType"
    :full-path="fullPath"
    :has-children="hasChildren"
    :has-parent="hasParent"
    :widgets="widgets"
    :allowed-child-types="allowedChildTypes"
    :namespace-full-name="namespaceFullName"
    :allowed-work-item-types-e-e="allowedWorkItems"
    :epic-field-note="epicFieldNote"
    :get-epic-widget-definitions="getEpicWidgetDefinitions"
    @workItemTypeChanged="$emit('workItemTypeChanged')"
    @promoteToEpic="promoteToEpic"
    @error="$emit('error', $event)"
  />
</template>
