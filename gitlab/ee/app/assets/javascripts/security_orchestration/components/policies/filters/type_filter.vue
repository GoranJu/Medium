<script>
import { GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import { validateTypeFilter } from 'ee/security_orchestration/components/policies/utils';
import { POLICY_TYPE_FILTER_OPTIONS } from '../constants';

export default {
  name: 'PolicyTypeFilter',
  components: {
    GlFormGroup,
    GlCollapsibleListbox,
  },
  props: {
    value: {
      type: String,
      required: true,
      validator: (value) => validateTypeFilter(value),
    },
  },
  computed: {
    listboxItems() {
      return Object.values(POLICY_TYPE_FILTER_OPTIONS).map((option) => ({
        value: option.value,
        text: option.text,
      }));
    },

    selectedValueText() {
      return Object.values(POLICY_TYPE_FILTER_OPTIONS).find(({ value }) => value === this.value)
        .text;
    },
  },
  methods: {
    setPolicyType(value) {
      this.$emit('input', value);
    },
  },
  policyTypeFilterId: 'policy-type-filter',
  i18n: {
    label: __('Type'),
  },
};
</script>

<template>
  <gl-form-group
    :label="$options.i18n.label"
    label-size="sm"
    :label-for="$options.policyTypeFilterId"
  >
    <gl-collapsible-listbox
      :id="$options.policyTypeFilterId"
      class="gl-flex"
      toggle-class="gl-truncate"
      block
      :toggle-text="selectedValueText"
      :items="listboxItems"
      :selected="value"
      @select="setPolicyType"
    />
  </gl-form-group>
</template>
