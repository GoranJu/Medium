<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import {
  ANY_OPERATOR,
  VULNERABILITY_AGE_OPERATORS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { enforceIntValue } from 'ee/security_orchestration/components/policy_editor/utils';
import NumberRangeSelect from '../number_range_select.vue';
import { AGE, AGE_DAY, AGE_INTERVALS } from './constants';

export default {
  i18n: {
    label: s__('ScanResultPolicy|Age is:'),
    headerText: __('Choose an option'),
  },
  name: 'AgeFilter',
  components: {
    SectionLayout,
    NumberRangeSelect,
    GlCollapsibleListbox,
  },
  props: {
    selected: {
      type: Object,
      required: false,
      default: () => ({ operator: ANY_OPERATOR, value: 0, interval: AGE_DAY }),
    },
    showRemoveButton: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    showInterval() {
      return this.selected.operator !== ANY_OPERATOR;
    },
    value() {
      return enforceIntValue(this.selected.value || 0);
    },
  },
  methods: {
    remove() {
      this.$emit('remove', AGE);
    },
    emitChange(data) {
      this.$emit('input', {
        operator: this.selected.operator,
        value: this.value,
        interval: this.selected.interval,
        ...data,
      });
    },
  },
  VULNERABILITY_AGE_OPERATORS,
  AGE_INTERVALS,
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-bg-white gl-pr-2"
    content-class="gl-bg-white gl-rounded-base gl-p-5"
    :show-remove-button="showRemoveButton"
    @remove="remove"
  >
    <template #selector>
      <label class="gl-mb-0" :title="$options.i18n.label">{{ $options.i18n.label }}</label>
      <number-range-select
        id="vulnerability-age-select"
        :value="value"
        :label="$options.i18n.headerText"
        :selected="selected.operator"
        :operators="$options.VULNERABILITY_AGE_OPERATORS"
        @input="emitChange({ value: $event })"
        @operator-change="emitChange({ operator: $event })"
      />
      <gl-collapsible-listbox
        v-if="showInterval"
        :selected="selected.interval"
        :header-text="$options.i18n.headerText"
        :items="$options.AGE_INTERVALS"
        @select="emitChange({ interval: $event })"
      />
    </template>
  </section-layout>
</template>
