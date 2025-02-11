<script>
import { GlPopover, GlLink } from '@gitlab/ui';
import { debounce, uniqBy } from 'lodash';
import produce from 'immer';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import getSppLinkedProjectGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups.graphql';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import BaseItemsDropdown from './base_items_dropdown.vue';

export default {
  ERROR_KEY: 'linked-items-query-error',
  SECURITY_POLICY_PROJECT_PATH: helpPagePath('user/application_security/policies/_index.md', {
    anchor: 'security-policy-project',
  }),
  i18n: {
    groupDropdownHeader: __('Select groups'),
    popoverTitle: s__('SecurityOrchestration|No linked groups'),
    popoverLink: s__('SecurityOrchestration|How do I link a group to the policy?'),
  },
  name: 'LinkedItemsDropdown',
  components: {
    GlPopover,
    GlLink,
    BaseItemsDropdown,
  },
  apollo: {
    linkedSppItems: {
      query: getSppLinkedProjectGroups,
      variables() {
        return {
          fullPath: this.fullPath,
          includeParentDescendants: this.includeDescendants,
          search: this.searchTerm,
        };
      },
      update(data) {
        const {
          securityPolicyProjectLinkedGroups: {
            nodes: linkedGroups = [],
            pageInfo: namespacePageInfo = {},
          } = {},
        } = data?.project || {};

        const descendants = this.flatMapDescendantGroups(linkedGroups);
        this.items = uniqBy([...this.items, ...linkedGroups, ...descendants], 'id');
        this.pageInfo = namespacePageInfo;

        this.$emit('loaded', this.items);
      },
      error() {
        this.$emit(this.$options.ERROR_KEY);
        this.$emit('loaded', this.items);
      },
    },
  },
  props: {
    includeDescendants: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullPath: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    state: {
      type: Boolean,
      required: false,
      default: false,
    },
    selected: {
      type: [Array, String],
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      items: [],
      pageInfo: {},
      linkedSppItems: {},
      searchTerm: '',
    };
  },
  computed: {
    category() {
      return this.state ? 'primary' : 'secondary';
    },
    variant() {
      return this.state ? 'default' : 'danger';
    },
    dropdownDisabled() {
      return this.disabled || this.showPopover;
    },
    loading() {
      return this.$apollo.queries.linkedSppItems.loading;
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
    existingFormattedSelectedIds() {
      return this.selected.filter((id) => this.itemsIds.includes(id));
    },
    showPopover() {
      return !this.loading && this.items.length === 0;
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    flatMapDescendantGroups(groups) {
      return groups.flatMap(({ descendantGroups }) => descendantGroups.nodes);
    },
    fetchMoreItems() {
      const variables = {
        after: this.pageInfo.endCursor,
        fullPath: this.fullPath,
      };

      this.$apollo.queries.linkedSppItems
        .fetchMore({
          variables,
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              draftData.project.securityPolicyProjectLinkedGroups.nodes = [
                ...previousResult.project.securityPolicyProjectLinkedGroups.nodes,
                ...draftData.project.securityPolicyProjectLinkedGroups.nodes,
              ];
            });
          },
        })
        .catch(() => {
          this.$emit(this.$options.ERROR_KEY);
        });
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    selectItems(selected) {
      const selectedItems = this.items.filter(({ id }) => selected.includes(id));
      this.$emit('select', selectedItems);
    },
  },
};
</script>

<template>
  <div>
    <gl-popover
      v-if="showPopover"
      boundary="viewport"
      triggers="manual blur"
      target="linked-groups"
      placement="bottom"
      show-close-button
      :show="true"
    >
      <p>{{ $options.i18n.popoverTitle }}</p>
      <gl-link :href="$options.SECURITY_POLICY_PROJECT_PATH" target="_blank">
        {{ $options.i18n.popoverLink }}
      </gl-link>
    </gl-popover>

    <base-items-dropdown
      id="linked-groups"
      multiple
      :category="category"
      :variant="variant"
      :disabled="dropdownDisabled"
      :loading="loading"
      :header-text="$options.i18n.groupDropdownHeader"
      :items="listBoxItems"
      :infinite-scroll="hasNextPage"
      :searching="searching"
      :selected="existingFormattedSelectedIds"
      :item-type-name="__('groups')"
      @bottom-reached="fetchMoreItems"
      @search="debouncedSearch"
      @reset="selectItems([])"
      @select="selectItems"
      @select-all="selectItems"
    />
  </div>
</template>
