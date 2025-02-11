<script>
import { GlTruncate, GlTooltipDirective } from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { difference } from 'lodash';
import { __, sprintf } from '~/locale';
import { formatSelectOptionForCustomField } from '~/work_items/utils';
import { CUSTOM_FIELDS_TYPE_MULTI_SELECT } from '~/work_items/constants';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';

export default {
  components: {
    GlTruncate,
    WorkItemSidebarDropdownWidget,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    workItemType: {
      type: String,
      required: false,
      default: '',
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    customField: {
      type: Object,
      required: true,
      validator: (customField) => {
        return (
          customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_MULTI_SELECT &&
          (customField.selectedOptions === null || Array.isArray(customField.selectedOptions))
        );
      },
    },
  },
  data() {
    return {
      searchTerm: '',
      searchStarted: false,
      isUpdating: false,
      addOptionsValues: [],
      removeOptionsValues: [],
      selectedOptionCache: [],
      optionsToShowAtTopOfTheListbox: [],
    };
  },
  computed: {
    customFieldId() {
      return this.customField.customField?.id;
    },
    dropdownLabel() {
      return this.customField.customField?.name;
    },
    headerText() {
      return sprintf(__('Select %{name}'), { name: this.dropdownLabel });
    },
    selectedOptionsCount() {
      return this.selectedOptions?.length ?? 0;
    },
    hasSelectedOptions() {
      return this.selectedOptionsCount > 0;
    },
    dropDownLabelText() {
      return this.selectedOptions?.map(({ text }) => text).join(', ');
    },
    dropdownText() {
      return this.hasSelectedOptions ? this.dropDownLabelText : __('None');
    },
    visibleOptions() {
      if (this.searchTerm) {
        return fuzzaldrinPlus.filter(this.defaultOptions, this.searchTerm, {
          key: ['text'],
        });
      }

      return this.defaultOptions;
    },
    optionsList() {
      const visibleOptions = this.visibleOptions || [];

      if (this.searchTerm || this.optionsValues.length === 0) {
        return visibleOptions;
      }

      const selectedOptions = this.optionsToShowAtTopOfTheListbox || [];
      const unselectedOptions = visibleOptions.filter(
        ({ value }) => !this.optionsToShowAtTopOfTheListbox.find((l) => l.value === value),
      );

      return [
        { options: selectedOptions, text: __('Selected') },
        { options: unselectedOptions, text: __('All'), textSrOnly: true },
      ];
    },
    optionsValues() {
      return this.optionsToShowAtTopOfTheListbox?.map(({ value }) => value) || [];
    },
    selectedOptions() {
      return this.optionsToShowAtTopOfTheListbox;
    },
    defaultOptions() {
      return (
        this.customField.customField?.selectOptions?.map(formatSelectOptionForCustomField) || []
      );
    },
    displayWidget() {
      return this.customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_MULTI_SELECT;
    },
    isValueValid() {
      return (
        this.customField.selectedOptions === null || Array.isArray(this.customField.selectedOptions)
      );
    },
  },
  watch: {
    searchTerm(newVal, oldVal) {
      if (newVal === '' && oldVal !== '') {
        const selectedValues = [...this.optionsValues, ...this.addOptionsValues].filter(
          (x) => !this.removeOptionsValues.includes(x),
        );

        this.optionsToShowAtTopOfTheListbox = this.selectedOptionCache.filter(({ value }) =>
          selectedValues.includes(value),
        );
      }
    },
  },
  beforeMount() {
    if (this.isValueValid) {
      this.optionsToShowAtTopOfTheListbox = this.customField.selectedOptions?.map(
        formatSelectOptionForCustomField,
      );
    }
  },
  methods: {
    onDropdownShown() {
      this.searchTerm = '';
      this.searchStarted = true;
    },
    search(searchTerm) {
      this.searchTerm = searchTerm;
      this.searchStarted = true;
    },
    updateSelection(labels) {
      this.removeOptionsValues = difference(this.itemValues, labels);
      this.addOptionsValues = difference(labels, this.itemValues);
    },
    async updateSelectedOptions(selectedOptionsValues) {
      this.isUpdating = true;

      if (selectedOptionsValues?.length === 0) {
        this.removeOptionsValues = this.itemValues;
        this.addOptionsValues = [];
      }
      // @todo add mutation logic

      this.searchTerm = '';
      this.addOptionsValues = [];
      this.removeOptionsValues = [];
      this.isUpdating = false;
    },
  },
};
</script>

<template>
  <work-item-sidebar-dropdown-widget
    v-if="displayWidget"
    :key="customFieldId"
    dropdown-name="select"
    :dropdown-label="dropdownLabel"
    :can-update="canUpdate"
    :list-items="optionsList"
    :item-value="optionsValues"
    :toggle-dropdown-text="dropdownText"
    :header-text="headerText"
    :update-in-progress="isUpdating"
    show-footer
    multi-select
    clear-search-on-item-select
    @dropdownShown="onDropdownShown"
    @searchStarted="search"
    @updateValue="updateSelectedOptions"
    @updateSelected="updateSelection"
  >
    <template #list-item="{ item }">
      <span class="gl-break-words">{{ item.text }}</span>
    </template>
    <template #readonly>
      <p
        v-for="option in optionsToShowAtTopOfTheListbox"
        :key="option.value"
        class="gl-fit-content gl-mb-2"
      >
        <gl-truncate v-gl-tooltip :title="option.text" :text="option.text" />
      </p>
    </template>
  </work-item-sidebar-dropdown-widget>
</template>
