<script>
import {
  GlLoadingIcon,
  GlTable,
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';

import { s__, __ } from '~/locale';
import { createAlert } from '~/alert';
import { emptyRequirement, requirementEvents } from '../constants';

import complianceRequirementControlsQuery from '../../../../graphql/compliance_requirement_controls.query.graphql';
import EditSection from './edit_section.vue';
import RequirementModal from './requirement_modal.vue';

export default {
  name: 'FrameworkRequirements',
  components: {
    EditSection,
    RequirementModal,
    GlLoadingIcon,
    GlTable,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  props: {
    requirements: {
      type: Array,
      required: true,
    },
    isNewFramework: {
      type: Boolean,
      required: true,
    },
  },
  apollo: {
    complianceRequirementControls: {
      query: complianceRequirementControlsQuery,
      update: (data) => data.complianceRequirementControls.controlExpressions || [],
      error(e) {
        createAlert({
          message: s__(
            'ComplianceFrameworks|Error fetching compliance requirements controls data. Please refresh the page.',
          ),
          captureException: true,
          error: e,
        });
      },
    },
  },
  data() {
    return {
      requirementToEdit: {},
      complianceRequirementControls: [],
    };
  },
  computed: {
    requirementsWithControls() {
      return this.requirements.map((requirement) => {
        const controls = this.getControls(requirement.controlExpression);
        return {
          ...requirement,
          controls,
        };
      });
    },
  },
  methods: {
    showRequirementModal(requirement, index = null) {
      this.requirementToEdit = { ...requirement, index };
      this.$nextTick(() => {
        this.$refs.requirementModal.show();
      });
    },
    handleCreate({ requirement, index }) {
      this.$emit(requirementEvents.create, { requirement, index });
      this.requirementToEdit = null;
    },
    handleUpdate({ requirement, index }) {
      this.$emit(requirementEvents.update, { requirement, index });
      this.requirementToEdit = null;
    },
    getControls(controlExpression) {
      if (!controlExpression) {
        return [];
      }
      try {
        const parsedExpression = JSON.parse(controlExpression);
        const conditions = parsedExpression.conditions || [];

        return conditions
          .map((condition) =>
            this.complianceRequirementControls.find((control) => control.id === condition.id),
          )
          .filter(Boolean);
      } catch (error) {
        return [];
      }
    },
  },
  tableFields: [
    {
      key: 'name',
      label: s__('ComplianceFrameworks|Requirement name'),
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-white',
    },
    {
      key: 'description',
      label: s__('ComplianceFrameworks|Description'),
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-white',
    },
    {
      key: 'controls',
      label: s__('ComplianceFrameworks|Controls'),
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-white',
    },
    {
      key: 'action',
      thAlignRight: true,
      label: s__('ComplianceFrameworks|Action'),
      thClass: 'gl-w-1 !gl-border-t-0 gl-w-1/10',
      tdClass: '!gl-text-right !gl-bg-white',
    },
  ],
  i18n: {
    requirements: s__('ComplianceFrameworks|Requirements'),
    requirementsDescription: s__(
      'ComplianceFrameworks|Configure requirements set forth by laws, regulations, and industry standards.',
    ),
    actionEdit: __('Edit'),
    actionDelete: __('Delete'),
    newRequirement: s__('ComplianceFrameworks|New requirement'),
  },
  emptyRequirement,
  requirementEvents,
};
</script>
<template>
  <edit-section
    :title="$options.i18n.requirements"
    :description="$options.i18n.requirementsDescription"
    :items-count="requirements.length"
    :initially-expanded="isNewFramework"
  >
    <gl-table
      v-if="requirements.length"
      ref="requirementsTable"
      class="requirements-table gl-mb-6"
      :items="requirementsWithControls"
      :fields="$options.tableFields"
      responsive
      stacked="md"
      hover
      select-mode="single"
      selected-variant="primary"
    >
      <template #cell(name)="{ item }">
        {{ item.name }}
      </template>
      <template #cell(description)="{ item }">
        {{ item.description }}
      </template>
      <template #cell(controls)="{ item }">
        <ul v-if="item.controls.length" class="gl-m-0 gl-pl-4">
          <li v-for="control in item.controls" :key="control.id">
            {{ control.name }}
          </li>
        </ul>
      </template>

      <template #cell(action)="{ item, index }">
        <gl-disclosure-dropdown
          icon="ellipsis_v"
          text-sr-only
          category="tertiary"
          placement="bottom-end"
          boundary="viewport"
          no-caret
        >
          <gl-disclosure-dropdown-item
            data-testid="edit-action"
            @action="showRequirementModal(item, index)"
          >
            <template #list-item>
              {{ $options.i18n.actionEdit }}
            </template>
          </gl-disclosure-dropdown-item>

          <gl-disclosure-dropdown-item
            data-testid="delete-action"
            @action="$emit($options.requirementEvents.delete, index)"
          >
            <template #list-item>
              {{ $options.i18n.actionDelete }}
            </template>
          </gl-disclosure-dropdown-item>
        </gl-disclosure-dropdown>
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" />
      </template>
    </gl-table>
    <gl-button
      variant="link"
      class="gl-ml-5"
      data-testid="add-requirement-button"
      @click="showRequirementModal($options.emptyRequirement)"
    >
      {{ $options.i18n.newRequirement }}
    </gl-button>

    <requirement-modal
      v-if="requirementToEdit"
      ref="requirementModal"
      :requirement-controls="complianceRequirementControls"
      :requirement="requirementToEdit"
      :is-new-framework="isNewFramework"
      @[$options.requirementEvents.create]="handleCreate"
      @[$options.requirementEvents.update]="handleUpdate"
    />
  </edit-section>
</template>
