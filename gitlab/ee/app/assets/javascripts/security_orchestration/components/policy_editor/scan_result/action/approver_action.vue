<script>
import { GlAlert, GlFormInput, GlIcon, GlPopover, GlSprintf } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { GROUP_TYPE, ROLE_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import {
  APPROVER_TYPE_DICT,
  APPROVER_TYPE_LIST_ITEMS,
  removeAvailableApproverType,
  createActionFromApprovers,
  actionHasType,
  getDefaultHumanizedTemplate,
  WARN_TEMPLATE,
  WARN_TEMPLATE_HELP_TITLE,
  WARN_TEMPLATE_HELP_DESCRIPTION,
} from '../lib/actions';
import SectionLayout from '../../section_layout.vue';
import ApproverSelectionWrapper from './approver_selection_wrapper.vue';

export default {
  warnId: 'warn-help-text',
  i18n: {
    WARN_TEMPLATE_HELP_TITLE,
    WARN_TEMPLATE_HELP_DESCRIPTION,
  },
  name: 'ApproverAction',
  components: {
    GlAlert,
    GlFormInput,
    GlIcon,
    GlPopover,
    GlSprintf,
    ApproverSelectionWrapper,
    SectionLayout,
  },
  inject: ['namespaceId'],
  props: {
    errors: {
      type: Array,
      required: false,
      default: () => [],
    },
    initAction: {
      type: Object,
      required: true,
    },
    isWarnType: {
      type: Boolean,
      required: false,
      default: false,
    },
    existingApprovers: {
      type: Object,
      required: true,
    },
    actionIndex: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  data() {
    const approverTypeTracker = [];
    let availableApproverTypes = [...APPROVER_TYPE_LIST_ITEMS];
    [GROUP_TYPE, ROLE_TYPE, USER_TYPE].forEach((type) => {
      if (actionHasType(this.initAction, type)) {
        availableApproverTypes = removeAvailableApproverType(availableApproverTypes, type);
        approverTypeTracker.push({ id: uniqueId(), type });
      }
    });

    return {
      approverTypeTracker: approverTypeTracker.length ? approverTypeTracker : [{ id: uniqueId() }],
      availableApproverTypes,
    };
  },
  computed: {
    actionErrors() {
      return this.errors.filter((error) => {
        if ('index' in error) {
          return error.index === this.actionIndex;
        }

        return error;
      });
    },
    approvalsRequired() {
      return this.initAction.approvals_required;
    },
    humanizedTemplate() {
      return this.isWarnType ? WARN_TEMPLATE : getDefaultHumanizedTemplate(this.approvalsRequired);
    },
    isApproverFieldValid() {
      return this.errors.every((error) => error.field !== 'approvers_ids');
    },
  },
  created() {
    this.updateRoleApprovers();
  },
  methods: {
    handleAddApproverType() {
      this.approverTypeTracker.push({ id: uniqueId() });
    },
    handleRemoveApproverType(approverIndex, approverType) {
      this.approverTypeTracker.splice(approverIndex, 1);

      if (approverType) {
        this.removeApproversByType(approverType);
      }
    },
    handleUpdateApprovalsRequired(value) {
      const updatedAction = { ...this.initAction, approvals_required: parseInt(value, 10) };
      this.updatePolicy(updatedAction);
    },
    handleUpdateApprovers(updatedExistingApprovers) {
      const updatedAction = createActionFromApprovers(this.initAction, updatedExistingApprovers);
      this.updatePolicy(updatedAction);
      this.$emit('updateApprovers', updatedExistingApprovers);
    },
    handleUpdateApproverType(approverIndex, { oldApproverType, newApproverType }) {
      this.approverTypeTracker[approverIndex].type = newApproverType;
      this.availableApproverTypes = removeAvailableApproverType(
        this.availableApproverTypes,
        newApproverType,
      );

      if (oldApproverType) {
        this.removeApproversByType(oldApproverType);
      }
    },
    removeApproversByType(approverType) {
      const updatedAction = Object.entries(this.initAction).reduce((acc, [key, value]) => {
        if (APPROVER_TYPE_DICT[approverType].includes(key)) {
          return acc;
        }

        acc[key] = value;
        return acc;
      }, {});
      this.updatePolicy(updatedAction);

      this.availableApproverTypes.push(
        APPROVER_TYPE_LIST_ITEMS.find((t) => t.value === approverType),
      );

      const updatedExistingApprovers = Object.keys(this.existingApprovers).reduce((acc, type) => {
        if (type !== approverType) {
          acc[type] = [...this.existingApprovers[type]];
        }
        return acc;
      }, {});
      this.$emit('updateApprovers', updatedExistingApprovers);
    },
    updatePolicy(updatedAction) {
      this.$emit('changed', updatedAction);
    },
    updateRoleApprovers() {
      const newApprovers = { ...this.existingApprovers };
      const roleApprovers = this.initAction[APPROVER_TYPE_DICT[ROLE_TYPE][0]];
      if (roleApprovers) {
        newApprovers[ROLE_TYPE] = roleApprovers;
      } else {
        delete newApprovers[ROLE_TYPE];
      }
      this.handleUpdateApprovers(newApprovers);
    },
    errorKey(error) {
      return error.index;
    },
  },
};
</script>

<template>
  <div>
    <gl-alert
      v-for="(error, index) in actionErrors"
      :key="errorKey(error)"
      :class="{ 'gl-mb-3': index === errors.length - 1 }"
      :dismissible="false"
      :title="error.title"
      variant="danger"
    >
      {{ error.message }}
    </gl-alert>
    <section-layout
      class="gl-pr-0"
      content-classes="gl-py-5 gl-pr-2 gl-bg-white"
      :show-remove-button="false"
    >
      <template #content>
        <div
          class="gl-mb-3 gl-ml-5"
          :class="{ 'gl-flex': !isWarnType, 'gl-items-center': !isWarnType }"
        >
          <gl-sprintf :message="humanizedTemplate">
            <template #require="{ content }">
              <strong>{{ content }}</strong>
            </template>

            <template #approvalsRequired>
              <gl-form-input
                :state="isApproverFieldValid"
                :value="approvalsRequired"
                data-testid="approvals-required-input"
                type="number"
                class="gl-mx-3 !gl-w-11"
                :min="1"
                :max="100"
                @update="handleUpdateApprovalsRequired"
              />
            </template>

            <template #approval="{ content }">
              <strong class="gl-mr-3">{{ content }}</strong>
            </template>
          </gl-sprintf>
          <template v-if="isWarnType">
            <gl-icon :id="$options.warnId" name="information-o" variant="info" class="gl-ml-3" />
            <gl-popover :target="$options.warnId" placement="bottom">
              <template #title>{{ $options.i18n.WARN_TEMPLATE_HELP_TITLE }}</template>
              {{ $options.i18n.WARN_TEMPLATE_HELP_DESCRIPTION }}
            </gl-popover>
          </template>
        </div>

        <approver-selection-wrapper
          v-for="({ id, type }, i) in approverTypeTracker"
          :key="id"
          :approver-index="i"
          :available-types="availableApproverTypes"
          :approver-type="type"
          :is-approver-field-valid="isApproverFieldValid"
          :num-of-approver-types="approverTypeTracker.length"
          :existing-approvers="existingApprovers"
          :show-additional-approver-text="i < approverTypeTracker.length - 1"
          :show-remove-button="approverTypeTracker.length > 1"
          @addApproverType="handleAddApproverType"
          @error="$emit('error')"
          @updateApprovers="handleUpdateApprovers"
          @updateApproverType="handleUpdateApproverType(i, $event)"
          @removeApproverType="handleRemoveApproverType(i, $event)"
        />
      </template>
    </section-layout>
  </div>
</template>
