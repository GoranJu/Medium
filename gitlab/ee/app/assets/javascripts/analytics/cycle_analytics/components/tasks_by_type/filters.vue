<script>
import { GlCollapsibleListbox, GlSegmentedControl } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters } from 'vuex';
import { difference, debounce } from 'lodash';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __, s__, n__, sprintf } from '~/locale';
import { getGroupLabels } from 'ee/api/analytics_api';
import { TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS, TASKS_BY_TYPE_MAX_LABELS } from '../../constants';
import { DATA_REFETCH_DELAY } from '../../../shared/constants';

export default {
  name: 'TasksByTypeFilters',
  components: {
    GlCollapsibleListbox,
    GlSegmentedControl,
  },
  props: {
    selectedLabelNames: {
      type: Array,
      required: true,
    },
    maxLabels: {
      type: Number,
      required: false,
      default: TASKS_BY_TYPE_MAX_LABELS,
    },
    subjectFilter: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      labels: [],
      searchTerm: '',
      searching: false,
      loading: false,
      debouncedSearch: null,
      maxLabelsAlert: null,
    };
  },
  computed: {
    ...mapState(['defaultGroupLabels']),
    ...mapGetters(['namespaceRestApiRequestPath']),
    subjectFilterOptions() {
      return Object.entries(TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS).map(([value, text]) => ({
        text,
        value,
      }));
    },
    selectedLabelsCount() {
      return this.selectedLabelNames.length;
    },
    maxLabelsSelected() {
      return this.selectedLabelNames.length >= this.maxLabels;
    },
    labelsSelectedText() {
      const { selectedLabelsCount, maxLabels } = this;
      return sprintf(
        n__(
          'CycleAnalytics|%{selectedLabelsCount} label selected (%{maxLabels} max)',
          'CycleAnalytics|%{selectedLabelsCount} labels selected (%{maxLabels} max)',
          selectedLabelsCount,
        ),
        { selectedLabelsCount, maxLabels },
      );
    },
    items() {
      return this.labels.map(({ title, color }) => ({ value: title, text: title, color }));
    },
    selected: {
      get() {
        return this.selectedLabelNames;
      },
      set(data) {
        const [addedLabel] = difference(data, this.selectedLabelNames);
        const [removedLabel] = difference(this.selectedLabelNames, data);
        this.toggleLabel(addedLabel || removedLabel);
      },
    },
  },
  watch: {
    searchTerm() {
      this.debouncedSearch();
    },
  },
  async mounted() {
    this.debouncedSearch = debounce(this.search, DATA_REFETCH_DELAY);

    if (!this.defaultGroupLabels?.length) {
      this.loading = true;
      await this.fetchLabels();
      this.loading = false;
    } else {
      this.labels = this.defaultGroupLabels;
    }
  },
  methods: {
    async fetchLabels() {
      try {
        const { data } = await getGroupLabels(this.namespaceRestApiRequestPath, {
          search: this.searchTerm,
          only_group_labels: true,
        });

        this.labels = data;
      } catch {
        createAlert({
          message: __('There was an error fetching label data for the selected group'),
        });
      }
    },
    async search() {
      this.searching = true;
      await this.fetchLabels();
      this.searching = false;
    },
    findLabel(title) {
      return this.labels.find((label) => label.title === title);
    },
    toggleLabel(title) {
      if (this.maxLabelsSelected && !this.selectedLabelNames.includes(title)) {
        this.createMaxLabelsSelectedAlert();
        return;
      }

      this.maxLabelsAlert?.dismiss();
      this.$emit('toggle-label', this.findLabel(title));
    },
    createMaxLabelsSelectedAlert() {
      const { maxLabels } = this;
      const message = sprintf(
        s__('CycleAnalytics|Only %{maxLabels} labels can be selected at this time'),
        { maxLabels },
      );
      this.maxLabelsAlert = createAlert({ message, variant: VARIANT_INFO });
    },
    setSearchTerm(value) {
      this.searchTerm = value;
    },
  },
};
</script>
<template>
  <div class="js-tasks-by-type-chart-filters">
    <gl-collapsible-listbox
      v-model="selected"
      :name="'test'"
      :header-text="s__('CycleAnalytics|Select labels')"
      :items="items"
      :loading="loading"
      :searching="searching"
      :no-results-text="__('No matching labels')"
      icon="settings"
      searchable
      multiple
      @search="setSearchTerm"
    >
      <template #list-item="{ item: { text, color } }">
        <span :style="{ backgroundColor: color }" class="dropdown-label-box gl-inline-block">
        </span>
        {{ text }}
      </template>
      <template #footer>
        <small
          v-if="selected.length > 0"
          data-testid="selected-labels-count"
          class="text-center gl-border-t-1 gl-border-t-dropdown !gl-p-2 gl-text-subtle gl-border-t-solid"
        >
          {{ labelsSelectedText }}
        </small>
        <div
          class="gl-flex gl-flex-col gl-border-t-1 gl-border-t-dropdown !gl-p-4 !gl-pt-3 gl-border-t-solid"
        >
          <p class="font-weight-bold text-left mb-2">{{ s__('CycleAnalytics|Show') }}</p>

          <gl-segmented-control
            :value="subjectFilter"
            :options="subjectFilterOptions"
            data-testid="type-of-work-filters-subject"
            @input="(value) => $emit('set-subject', value)"
          />
        </div>
      </template>
    </gl-collapsible-listbox>
  </div>
</template>
