<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import {
  CUSTOM_STRATEGY_OPTIONS,
  CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS,
  INJECT,
} from '../constants';
import { validateStrategyValues } from './utils';

export default {
  CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS,
  name: 'CodeBlockStrategySelector',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    strategy: {
      type: String,
      required: false,
      default: INJECT,
      validator: validateStrategyValues,
    },
  },
  computed: {
    toggleText() {
      return CUSTOM_STRATEGY_OPTIONS[this.strategy];
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    label-for="file-path"
    data-testid="strategy-selector-dropdown"
    :items="$options.CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS"
    :toggle-text="toggleText"
    :selected="strategy"
    @select="$emit('select', $event)"
  />
</template>
