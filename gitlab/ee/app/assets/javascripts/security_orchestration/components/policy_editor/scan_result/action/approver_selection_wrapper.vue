<script>
import {
  GlButton,
  GlForm,
  GlFormInput,
  GlCollapsibleListbox,
  GlSprintf,
  GlBadge,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { GROUP_TYPE, ROLE_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import SectionLayout from '../../section_layout.vue';
import {
  ADD_APPROVER_LABEL,
  APPROVER_TYPE_LIST_ITEMS,
  DEFAULT_APPROVER_DROPDOWN_TEXT,
} from '../lib/actions';
import GroupSelect from './group_select.vue';
import RoleSelect from './role_select.vue';
import UserSelect from './user_select.vue';

export default {
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    SectionLayout,
    GlBadge,
    GlButton,
    GlForm,
    GlFormInput,
    GlCollapsibleListbox,
    GlSprintf,
    GroupSelect,
    RoleSelect,
    UserSelect,
  },
  inject: ['namespaceId'],
  props: {
    approverIndex: {
      type: Number,
      required: true,
    },
    availableTypes: {
      type: Array,
      required: true,
    },
    isApproverFieldValid: {
      type: Boolean,
      required: false,
      default: true,
    },
    existingApprovers: {
      type: Object,
      required: true,
    },
    numOfApproverTypes: {
      type: Number,
      required: true,
    },
    approverType: {
      type: String,
      required: false,
      default: '',
    },
    showAdditionalApproverText: {
      type: Boolean,
      required: false,
      default: false,
    },
    showRemoveButton: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    approverTypeToggleText() {
      return this.approverType ? this.selected : DEFAULT_APPROVER_DROPDOWN_TEXT;
    },
    approverComponent() {
      switch (this.approverType) {
        case GROUP_TYPE:
          return GroupSelect;
        case ROLE_TYPE:
          return RoleSelect;
        case USER_TYPE:
        default:
          return UserSelect;
      }
    },
    hasAvailableTypes() {
      return Boolean(this.availableTypes.length);
    },
    selected() {
      return APPROVER_TYPE_LIST_ITEMS.find((v) => v.value === this.approverType)?.text;
    },
    showAddButton() {
      return (
        this.approverIndex + 1 < APPROVER_TYPE_LIST_ITEMS.length &&
        this.approverIndex + 1 === this.numOfApproverTypes
      );
    },
    listBoxItems() {
      return APPROVER_TYPE_LIST_ITEMS.map(({ value, text }) => ({
        value,
        text,
        disabled:
          this.isMissingFromAvailableTypes(value) && this.hasExistingApproversSelected(value),
      }));
    },
  },
  methods: {
    addApproverType() {
      this.$emit('addApproverType');
    },
    handleApproversUpdate({ updatedApprovers, type }) {
      const updatedExistingApprovers = { ...this.existingApprovers };
      updatedExistingApprovers[type] = updatedApprovers;
      this.$emit('updateApprovers', updatedExistingApprovers);
    },
    handleSelectedApproverType(newType) {
      const alreadySelected = this.availableTypes.find((v) => v.value === newType) === undefined;
      if (alreadySelected) return;

      this.$emit('updateApproverType', {
        newApproverType: newType,
        oldApproverType: this.approverType,
      });
    },
    handleRemoveApprover() {
      this.$emit('removeApproverType', this.approverType);
    },
    hasExistingApproversSelected(type) {
      return this.existingApprovers[type]?.length > 0;
    },
    isMissingFromAvailableTypes(type) {
      return this.availableTypes.find(({ value }) => value === type) === undefined;
    },
  },
  i18n: {
    ADD_APPROVER_LABEL,
    disabledLabel: __('disabled'),
    disabledTitle: s__('SecurityOrchestration|You can select this option only once.'),
    multipleApproverTypesHumanizedTemplate: __('or'),
  },
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-items-end gl-rounded-none gl-bg-white gl-py-0 gl-pr-0 md:gl-items-start"
    content-classes="gl-flex gl-w-full "
    :show-remove-button="showRemoveButton"
    @remove="handleRemoveApprover"
  >
    <template #content>
      <gl-form
        class="gl-w-full gl-flex-wrap gl-items-center md:gl-flex md:gl-gap-y-3"
        @submit.prevent
      >
        <gl-collapsible-listbox
          class="gl-mx-0 gl-mb-3 gl-block md:gl-mb-0 md:gl-mr-3"
          data-testid="available-types"
          :items="listBoxItems"
          :selected="selected"
          :toggle-text="approverTypeToggleText"
          :disabled="!hasAvailableTypes"
          @select="handleSelectedApproverType"
        >
          <template #list-item="{ item }">
            <span
              class="gl-flex"
              data-testid="list-item-content"
              :class="{ '!gl-cursor-default': item.disabled }"
            >
              <span
                :id="item.value"
                data-testid="list-item-text"
                class="gl-pr-3"
                :class="{ 'gl-text-subtle': item.disabled }"
              >
                {{ item.text }}
              </span>
              <gl-badge
                v-if="item.disabled"
                v-gl-tooltip.right.viewport
                :title="$options.i18n.disabledTitle"
                class="gl-ml-auto"
                variant="neutral"
              >
                {{ $options.i18n.disabledLabel }}
              </gl-badge>
            </span>
          </template>
        </gl-collapsible-listbox>

        <template v-if="approverType">
          <component
            :is="approverComponent"
            :existing-approvers="existingApprovers[approverType]"
            :state="isApproverFieldValid"
            class="security-policies-approver-max-width"
            @error="$emit('error')"
            @updateSelectedApprovers="
              handleApproversUpdate({
                updatedApprovers: $event,
                type: approverType,
              })
            "
          />
        </template>
        <p
          v-if="showAdditionalApproverText"
          class="gl-mb-0 gl-ml-0 gl-mt-2 md:gl-mb-2 md:gl-ml-3 md:gl-mt-2"
        >
          {{ $options.i18n.multipleApproverTypesHumanizedTemplate }}
        </p>
      </gl-form>
      <gl-button
        v-if="showAddButton"
        class="gl-ml-2 gl-mt-4"
        variant="link"
        data-testid="add-approver"
        @click="addApproverType"
      >
        {{ $options.i18n.ADD_APPROVER_LABEL }}
      </gl-button>
    </template>
  </section-layout>
</template>
