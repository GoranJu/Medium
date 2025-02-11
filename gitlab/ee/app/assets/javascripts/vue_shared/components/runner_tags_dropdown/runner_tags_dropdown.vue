<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { debounce, uniq } from 'lodash';
import { s__, __ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import projectRunnerTags from './graphql/get_project_runner_tags.query.graphql';
import groupRunnerTags from './graphql/get_group_runner_tags.query.graphql';
import { NAMESPACE_TYPES } from './constants';
import { getUniqueTagListFromEdges } from './utils';

export default {
  i18n: {
    noRunnerTagsText: s__('RunnerTags|No tags exist'),
    runnerEmptyStateText: s__('RunnerTags|No matching results'),
    runnerSearchHeader: s__('RunnerTags|Select runner tags'),
    resetButtonLabel: __('Clear all'),
    selectAllButtonLabel: __('Select all'),
  },
  name: 'RunnerTagsDropdown',
  components: {
    GlCollapsibleListbox,
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    tagList: {
      query() {
        return this.tagListQuery;
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          tagList: this.search,
        };
      },
      update(data) {
        const {
          [this.namespaceType]: {
            runners: { nodes = [] },
          },
        } = data;
        this.tags = uniq([...this.tags, ...getUniqueTagListFromEdges(nodes)]);
        this.selectExistingTags();
        this.sortTags();

        this.$emit('tags-loaded', this.tags);
      },
      error(error) {
        this.$emit('error', error);
      },
    },
  },
  props: {
    block: {
      type: Boolean,
      required: false,
      default: false,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    namespaceType: {
      type: String,
      required: false,
      default: NAMESPACE_TYPES.PROJECT,
    },
    namespacePath: {
      type: String,
      required: false,
      default: '',
    },
    value: {
      type: Array,
      required: false,
      default: () => [],
    },
    headerText: {
      type: String,
      required: false,
      default: '',
    },
    emptyTagsListPlaceholder: {
      type: String,
      required: false,
      default: '',
    },
    toggleClass: {
      type: [String, Array, Object],
      required: false,
      default: null,
    },
  },
  data() {
    return {
      search: '',
      tags: [],
      selected: [],
    };
  },
  computed: {
    items() {
      return this.tags
        .filter((tag) => tag.includes(this.search))
        .map((tag) => ({ text: tag, value: tag }));
    },
    isDropdownDisabled() {
      return this.disabled || (this.isTagListEmpty && !this.isSearching);
    },
    isProject() {
      return this.namespaceType === NAMESPACE_TYPES.PROJECT;
    },
    isSearching() {
      return this.search.length > 0;
    },
    isTagListEmpty() {
      return this.tags.length === 0;
    },
    loading() {
      return this.$apollo.queries.tagList?.loading || false;
    },
    runnerSearchHeader() {
      return this.headerText || this.$options.i18n.runnerSearchHeader;
    },
    text() {
      if (this.isTagListEmpty && !this.selected.length) {
        return this.emptyTagsListPlaceholder || this.$options.i18n.noRunnerTagsText;
      }

      return this.selected?.join(', ') || this.$options.i18n.runnerSearchHeader;
    },
    tagListQuery() {
      return this.isProject ? projectRunnerTags : groupRunnerTags;
    },
  },
  created() {
    this.debouncedSearchKeyUpdate = debounce(this.setSearchKey, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  methods: {
    isTagSelected(tag) {
      return this.selected?.includes(tag);
    },
    doesTagExist(tag) {
      return this.tags.includes(tag) || this.selected.includes(tag);
    },
    sortTags() {
      this.tags.sort((a) => (this.isTagSelected(a) ? -1 : 1));
    },
    setSearchKey(value) {
      this.search = value?.trim();
    },
    setSelection(tags) {
      this.selected = tags;
      this.$emit('input', this.selected);
    },
    selectExistingTags() {
      if (this.value.length > 0) {
        const nonExistingTags = this.value.filter((tag) => !this.doesTagExist(tag));

        if (nonExistingTags.length > 0) {
          this.$emit('error');
          return;
        }

        this.selected = this.value;
      }
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    multiple
    searchable
    :block="block"
    :disabled="isDropdownDisabled"
    :toggle-class="toggleClass"
    :items="items"
    :loading="loading"
    :header-text="runnerSearchHeader"
    :no-caret="isTagListEmpty"
    :no-results-text="$options.i18n.runnerEmptyStateText"
    :selected="selected"
    :reset-button-label="$options.i18n.resetButtonLabel"
    :show-select-all-button-label="$options.i18n.selectAllButtonLabel"
    :toggle-text="text"
    @hidden="sortTags"
    @reset="setSelection([])"
    @search="debouncedSearchKeyUpdate"
    @select="setSelection"
    @select-all="setSelection(tags)"
  />
</template>
