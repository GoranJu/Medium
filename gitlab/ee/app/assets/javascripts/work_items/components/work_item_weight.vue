<script>
import { GlButton, GlForm, GlFormInput, GlLoadingIcon, GlTooltipDirective } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Tracking from '~/tracking';
import {
  sprintfWorkItem,
  I18N_WORK_ITEM_ERROR_UPDATING,
  TRACKING_CATEGORY_SHOW,
} from '~/work_items/constants';
import updateNewWorkItemMutation from '~/work_items/graphql/update_new_work_item.mutation.graphql';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import { newWorkItemId } from '~/work_items/utils';

export default {
  inputId: 'weight-widget-input',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
    GlForm,
    GlFormInput,
    GlLoadingIcon,
  },
  mixins: [Tracking.mixin()],
  inject: ['hasIssueWeightsFeature'],
  props: {
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullPath: {
      type: String,
      required: true,
    },
    widget: {
      type: Object,
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
      isEditing: false,
      clickingClearButton: false,
      workItem: {},
      isUpdating: false,
    };
  },
  computed: {
    weight() {
      return this.widget.weight;
    },
    hasWeight() {
      return this.weight !== null;
    },
    showRemoveWeight() {
      return this.hasWeight && !this.isUpdating;
    },
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_weight',
        property: `type_${this.workItemType}`,
      };
    },
    createFlow() {
      return this.workItemId === newWorkItemId(this.workItemType);
    },
    isWorkItemWidgetAvailable() {
      // `editable` means if it is available for that work item type (not related to user permission)
      return this.widget?.widgetDefinition?.editable;
    },
    displayWeightWidget() {
      return this.hasIssueWeightsFeature && this.isWorkItemWidgetAvailable;
    },
  },
  methods: {
    blurInput() {
      this.$refs.input.$el.blur();
    },
    handleFocus() {
      this.isEditing = true;
    },
    updateWeightFromInput(event) {
      if (event.target.value === '') {
        this.updateWeight(null);
        return;
      }

      const weight = Number(event.target.value);
      this.updateWeight(weight);
    },
    updateWeight(weight) {
      if (this.clickingClearButton) return;
      if (!this.canUpdate) return;

      if (this.weight === weight) {
        this.isEditing = false;
        return;
      }

      this.isUpdating = true;

      this.track('updated_weight');

      if (this.createFlow) {
        this.$apollo.mutate({
          mutation: updateNewWorkItemMutation,
          variables: {
            input: {
              workItemType: this.workItemType,
              fullPath: this.fullPath,
              weight,
            },
          },
        });

        this.isUpdating = false;
        this.isEditing = false;
        return;
      }

      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              weightWidget: {
                weight,
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
          this.isUpdating = false;
          this.isEditing = false;
        });
    },
  },
};
</script>

<template>
  <div v-if="displayWeightWidget" data-testid="work-item-weight">
    <div class="gl-flex gl-items-center gl-justify-between">
      <!-- hide header when editing, since we then have a form label. Keep it reachable for screenreader nav  -->
      <h3 :class="{ 'gl-sr-only': isEditing }" class="gl-heading-5 !gl-mb-0">
        {{ __('Weight') }}
      </h3>
      <gl-button
        v-if="canUpdate && !isEditing"
        data-testid="edit-weight"
        category="tertiary"
        size="small"
        @click="isEditing = true"
        >{{ __('Edit') }}</gl-button
      >
    </div>
    <gl-form v-if="isEditing" @submit.prevent="blurInput">
      <div class="gl-flex gl-items-center">
        <label :for="$options.inputId" class="gl-mb-0">{{ __('Weight') }}</label>
        <gl-loading-icon v-if="isUpdating" size="sm" inline class="gl-ml-3" />
        <gl-button
          data-testid="apply-weight"
          category="tertiary"
          size="small"
          class="gl-ml-auto"
          :disabled="isUpdating"
          @click="isEditing = false"
          >{{ __('Apply') }}</gl-button
        >
      </div>
      <!-- wrapper for the form input so the borders fit inside the sidebar -->
      <div class="gl-relative gl-px-2">
        <gl-form-input
          :id="$options.inputId"
          ref="input"
          min="0"
          class="hide-unfocused-input-decoration gl-block"
          type="number"
          :disabled="isUpdating"
          :placeholder="__('Enter a number')"
          :value="weight"
          autofocus
          @blur="updateWeightFromInput"
          @focus="handleFocus"
          @keydown.exact.esc.stop="blurInput"
        />
        <gl-button
          v-if="showRemoveWeight"
          v-gl-tooltip
          data-testid="remove-weight"
          variant="default"
          category="tertiary"
          size="small"
          name="clear"
          icon="clear"
          class="gl-clear-icon-button gl-absolute gl-right-7 gl-top-2"
          :title="__('Remove weight')"
          :aria-label="__('Remove weight')"
          @mousedown="clickingClearButton = true"
          @mouseup="clickingClearButton = false"
          @click="updateWeight(null)"
        />
      </div>
    </gl-form>
    <template v-else-if="hasWeight">
      <div>{{ weight }}</div>
    </template>
    <template v-else>
      <div class="gl-text-subtle">{{ __('None') }}</div>
    </template>
  </div>
</template>
