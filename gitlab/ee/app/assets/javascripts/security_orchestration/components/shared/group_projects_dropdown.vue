<script>
import { debounce, uniqBy, get } from 'lodash';
import produce from 'immer';
import { __ } from '~/locale';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_for_policies.query.graphql';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import getProjects from 'ee/security_orchestration/graphql/queries/get_projects.query.graphql';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import BaseItemsDropdown from './base_items_dropdown.vue';

export default {
  i18n: {
    projectDropdownHeader: __('Select projects'),
    groupDropdownHeader: __('Select groups'),
  },
  name: 'GroupProjectsDropdown',
  components: {
    BaseItemsDropdown,
  },
  apollo: {
    groups: {
      query: getGroups,
      variables() {
        return {
          search: this.searchTerm,
        };
      },
      update(data) {
        /**
         * It is important to preserve all groups that have been loaded
         * otherwise after performing backend search and selecting found item
         * selection is overwritten
         */
        return uniqBy([...this.groups, ...data.groups.nodes], 'id');
      },
      result({ data }) {
        this.pageInfo = data?.groups?.pageInfo || {};
      },
      error() {
        this.$emit('groups-query-error');
      },
      skip() {
        return !this.groupsOnly;
      },
    },
    projects: {
      query() {
        return this.loadAllProjects ? getProjects : getGroupProjects;
      },
      variables() {
        return {
          ...this.pathVariable,
          search: this.searchTerm,
        };
      },
      update(data) {
        /**
         * It is important to preserve all projects that has benn loaded
         * otherwise after performing backend search and selecting found item
         * selection is overwritten
         */
        const payload = this.loadAllProjects ? data.projects.nodes : data.group.projects.nodes;
        return uniqBy([...this.projects, ...payload], 'id');
      },
      result({ data }) {
        const payload = this.loadAllProjects ? data?.projects : data?.group?.projects;
        this.pageInfo = payload?.pageInfo || {};
      },
      error() {
        this.$emit('projects-query-error');
      },
      skip() {
        return this.groupsOnly;
      },
    },
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupFullPath: {
      type: String,
      required: true,
    },
    placement: {
      type: String,
      required: false,
      default: 'bottom-start',
    },
    selected: {
      type: [Array, String],
      required: false,
      default: () => [],
    },
    multiple: {
      type: Boolean,
      required: false,
      default: true,
    },
    state: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupsOnly: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    loadAllProjects: {
      type: Boolean,
      required: false,
      default: false,
    },
    isGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      pageInfo: {},
      searchTerm: '',
      projects: [],
      groups: [],
    };
  },
  computed: {
    itemsQuery() {
      return this.$apollo.queries[this.groupsOnly ? 'groups' : 'projects'];
    },
    filteredProjects() {
      if (this.groupIds.length === 0) {
        return this.projects;
      }

      return this.projects.filter(({ group = {} }) => this.groupIds.includes(group.id));
    },
    items() {
      return this.groupsOnly ? this.groups : this.filteredProjects;
    },
    itemTypeName() {
      return this.isGroup ? __('groups') : __('projects');
    },
    headerText() {
      return this.groupsOnly
        ? this.$options.i18n.groupDropdownHeader
        : this.$options.i18n.projectDropdownHeader;
    },
    existingFormattedSelectedIds() {
      if (this.multiple) {
        return this.selected.filter((id) => this.itemsIds.includes(id));
      }

      return this.selected;
    },
    loading() {
      return this.itemsQuery.loading;
    },
    searching() {
      return this.loading && this.searchUsed && !this.hasNextPage;
    },
    searchUsed() {
      return this.searchTerm !== '';
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
    listBoxItems() {
      const items = this.items.map(({ id, fullPath, name }) => ({
        text: name,
        value: id,
        fullPath,
      }));
      return searchInItemsProperties({
        items,
        properties: ['text', 'fullPath'],
        searchQuery: this.searchTerm,
      });
    },
    itemsIds() {
      return this.items.map(({ id }) => id);
    },
    category() {
      return this.state ? 'primary' : 'secondary';
    },
    variant() {
      return this.state ? 'default' : 'danger';
    },
    pathVariable() {
      return {
        ...(this.loadAllProjects ? {} : { fullPath: this.groupFullPath }),
      };
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    fetchMoreItems() {
      const { groupsOnly, loadAllProjects } = this;
      const variables = {
        after: this.pageInfo.endCursor,
        ...this.pathVariable,
      };

      this.itemsQuery
        .fetchMore({
          variables,
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              if (groupsOnly) {
                draftData.group.nodes = [...previousResult.group.nodes, ...draftData.group.nodes];
              } else {
                const getSourceObject = (source) => {
                  const path = loadAllProjects ? 'projects' : 'group.projects';
                  return get(source, path);
                };

                getSourceObject(draftData).nodes = [
                  ...getSourceObject(previousResult).nodes,
                  ...getSourceObject(draftData).nodes,
                ];
              }
            });
          },
        })
        .catch(() => {
          this.$emit('projects-query-error');
        });
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    selectItems(selected) {
      const ids = this.multiple ? selected : [selected];
      const selectedItems = this.items.filter(({ id }) => ids.includes(id));
      const payload = this.multiple ? selectedItems : selectedItems[0];
      this.$emit('select', payload);
    },
  },
};
</script>

<template>
  <base-items-dropdown
    :category="category"
    :variant="variant"
    :disabled="disabled"
    :multiple="multiple"
    :loading="loading"
    :header-text="headerText"
    :items="listBoxItems"
    :infinite-scroll="hasNextPage"
    :searching="searching"
    :selected="existingFormattedSelectedIds"
    :placement="placement"
    :item-type-name="itemTypeName"
    @bottom-reached="fetchMoreItems"
    @search="debouncedSearch"
    @reset="selectItems([])"
    @select="selectItems"
    @select-all="selectItems"
  />
</template>
