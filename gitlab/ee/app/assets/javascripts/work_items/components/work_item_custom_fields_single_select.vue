<script>
import { GlTruncate, GlTooltipDirective } from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { __, sprintf } from '~/locale';
import { formatSelectOptionForCustomField } from '~/work_items/utils';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import { CUSTOM_FIELDS_TYPE_SINGLE_SELECT } from '~/work_items/constants';

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
          customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_SINGLE_SELECT &&
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
      selectedOption: null,
      selectedOptionCache: null,
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
    editingValueText() {
      return this.selectedOption?.text || __('None');
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

      if (this.searchTerm || !this.optionValue) {
        return visibleOptions;
      }

      const unselectedOptions = visibleOptions.filter(
        ({ value }) => value !== this.selectedOption?.value,
      );

      return [
        { options: [this.selectedOption], text: __('Selected') },
        { options: unselectedOptions, text: __('All'), textSrOnly: true },
      ];
    },
    optionValue() {
      return this.selectedOption?.value;
    },
    defaultOptions() {
      return (
        this.customField.customField?.selectOptions?.map(formatSelectOptionForCustomField) || []
      );
    },
    displayWidget() {
      return this.customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_SINGLE_SELECT;
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
        this.selectedOption = this.selectedOptionCache;
      }
    },
  },
  beforeMount() {
    if (this.isValueValid) {
      this.selectedOption =
        this.customField.selectedOptions?.map(formatSelectOptionForCustomField)?.[0] || null;

      this.selectedOptionCache = this.selectedOption;
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
    async updateSelectedOption(selectedOption) {
      this.selectedOption = selectedOption;
      this.selectedOptionCache = selectedOption;

      // @todo add mutation logic
    },
  },
};
</script>

<template>
  <work-item-sidebar-dropdown-widget
    v-if="displayWidget"
    :key="customFieldId"
    dropdown-name="single-select"
    :dropdown-label="dropdownLabel"
    :can-update="canUpdate"
    :list-items="optionsList"
    :item-value="optionValue"
    :toggle-dropdown-text="editingValueText"
    :header-text="headerText"
    :update-in-progress="isUpdating"
    show-footer
    clear-search-on-item-select
    @dropdownShown="onDropdownShown"
    @searchStarted="search"
    @updateValue="updateSelectedOption"
  >
    <template #list-item="{ item }">
      <span class="gl-break-words">{{ item.text }}</span>
    </template>
    <template #readonly>
      <span v-gl-tooltip :title="editingValueText">
        <gl-truncate :text="editingValueText" />
      </span>
    </template>
  </work-item-sidebar-dropdown-widget>
</template>
