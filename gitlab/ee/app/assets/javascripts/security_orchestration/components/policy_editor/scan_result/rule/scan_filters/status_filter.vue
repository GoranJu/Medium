<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { groupSelectedVulnerabilityStates } from '../../lib';
import {
  NEWLY_DETECTED,
  APPROVAL_VULNERABILITY_STATE_GROUPS,
  APPROVAL_VULNERABILITY_STATES,
  DEFAULT_VULNERABILITY_STATES,
} from './constants';

export default {
  APPROVAL_VULNERABILITY_STATE_GROUPS,
  APPROVAL_VULNERABILITY_STATES,
  i18n: {
    headerText: __('Choose an option'),
    vulnerabilityStates: s__('ScanResultPolicy|vulnerability states'),
  },
  name: 'StatusFilter',
  components: {
    RuleMultiSelect,
    SectionLayout,
    GlCollapsibleListbox,
  },
  props: {
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
    filter: {
      type: String,
      required: false,
      default: NEWLY_DETECTED,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    showRemoveButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    label: {
      type: String,
      required: false,
      default: s__('ScanResultPolicy|Status is:'),
    },
    labelClasses: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      filters: groupSelectedVulnerabilityStates(this.selected)[this.filter],
      selectedFilter: this.filter,
    };
  },
  computed: {
    vulnerabilityStateGroups() {
      return Object.entries(APPROVAL_VULNERABILITY_STATE_GROUPS).map(([value, text]) => ({
        value,
        text,
      }));
    },
  },
  methods: {
    remove() {
      this.$emit('remove', this.filter);
    },
    selectVulnerabilityStateGroup(value) {
      this.selectedFilter = value;
      this.filters = value === NEWLY_DETECTED ? DEFAULT_VULNERABILITY_STATES : [];
      this.$emit('change-group', value);
    },
    emitVulnerabilityStates(value) {
      this.filters = value;
      const selectedStates = Object.values(this.filters).flatMap((states) => states);
      this.$emit('input', selectedStates);
    },
  },
};
</script>

<template>
  <section-layout
    :key="filter"
    class="gl-w-full gl-bg-white gl-pr-2"
    :rule-label="label"
    :label-classes="labelClasses"
    :show-remove-button="showRemoveButton"
    @remove="remove"
  >
    <template #content>
      <slot>
        <gl-collapsible-listbox
          :header-text="$options.i18n.headerText"
          :items="vulnerabilityStateGroups"
          :selected="selectedFilter"
          :disabled="disabled"
          @select="selectVulnerabilityStateGroup"
        />
        <rule-multi-select
          :value="filters"
          :item-type-name="$options.i18n.vulnerabilityStates"
          :items="$options.APPROVAL_VULNERABILITY_STATES[selectedFilter]"
          data-testid="vulnerability-states-select"
          @input="emitVulnerabilityStates"
        />
      </slot>
    </template>
  </section-layout>
</template>
