<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'SortingField',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    sortBy: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    sortingItems() {
      return [
        {
          value: 'created_desc',
          text: s__('SortOptions|Last created'),
        },
        {
          value: 'created_asc',
          text: s__('SortOptions|Oldest created'),
        },
      ];
    },
    selectedItem() {
      return (
        this.sortingItems.find((option) => option.value === this.sortBy) || this.sortingItems[0]
      );
    },
  },
  methods: {
    onItemSelect(option) {
      this.$emit('selected', option);
    },
  },
  i18n: {
    sorting_title: s__('SortOptions|Sort by'),
  },
};
</script>

<template>
  <gl-collapsible-listbox
    toggle-class="gl-flex-grow"
    is-check-centered
    :items="sortingItems"
    :header-text="$options.i18n.sorting_title"
    :toggle-text="selectedItem.text"
    :selected="selectedItem.value"
    @select="onItemSelect"
  />
</template>
