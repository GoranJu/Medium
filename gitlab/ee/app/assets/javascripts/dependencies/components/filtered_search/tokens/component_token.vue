<script>
import {
  GlIcon,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlLoadingIcon,
  GlIntersperse,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from 'ee/dependencies/constants';
import groupComponentsQuery from 'ee/dependencies/graphql/group_components.query.graphql';
import projectComponentsQuery from 'ee/dependencies/graphql/project_components.query.graphql';

export default {
  components: {
    GlIcon,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
    GlIntersperse,
  },
  inject: ['namespaceType', 'groupFullPath', 'projectFullPath'],
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      searchTerm: '',
      components: [],
      selectedComponents: [],
    };
  },
  computed: {
    isLoadingComponents() {
      return this.$apollo.queries.components.loading;
    },
    filteredComponents() {
      if (!this.searchTerm) {
        return this.components;
      }

      const nameIncludesSearchTerm = (component) =>
        component.name.toLowerCase().includes(this.searchTerm);
      const isSelected = (component) => this.selectedComponentNames.includes(component.name);

      return this.components.filter(
        (component) => nameIncludesSearchTerm(component) || isSelected(component),
      );
    },
    selectedComponentNames() {
      return this.selectedComponents.map(({ name }) => name);
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2381
        data: this.active ? null : this.selectedComponentNames,
      };
    },
    componentsQueryType() {
      const queryTypes = {
        [NAMESPACE_GROUP]: {
          query: groupComponentsQuery,
          fullPath: this.groupFullPath,
        },
        [NAMESPACE_PROJECT]: {
          query: projectComponentsQuery,
          fullPath: this.projectFullPath,
        },
      };

      return queryTypes[this.namespaceType];
    },
    fetchErrorMessage() {
      return sprintf(
        s__(
          'Dependencies|There was an error fetching the components for this %{namespaceType}. Please try again later.',
        ),
        { namespaceType: this.namespaceType },
      );
    },
  },
  apollo: {
    components: {
      query() {
        return this.componentsQueryType.query;
      },
      debounce: 300,
      variables() {
        return {
          name: this.searchTerm,
          fullPath: this.componentsQueryType.fullPath,
        };
      },
      update(data) {
        // Remove __typename
        return data[this.namespaceType]?.components?.map(({ id, name }) => ({ name, id }));
      },
      error() {
        createAlert({
          message: this.fetchErrorMessage,
        });
      },
      skip() {
        return this.searchTerm === '';
      },
    },
  },
  methods: {
    isComponentSelected(component) {
      return this.selectedComponents.some((c) => c.id === component.id);
    },
    toggleSelectedComponent(component) {
      if (this.isComponentSelected(component)) {
        this.selectedComponents = this.selectedComponents.filter((c) => c.id !== component.id);
      } else {
        this.selectedComponents.push(component);
      }
    },
    setSearchTerm(token) {
      // the data can be either a string or an array, in which case we don't want to perform the search
      if (typeof token.data === 'string') {
        this.searchTerm = token.data.toLowerCase();
      }
    },
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedComponentNames"
    :value="tokenValue"
    v-on="$listeners"
    @select="toggleSelectedComponent"
    @input="setSearchTerm"
  >
    <template #view>
      <gl-intersperse data-testid="selected-components">
        <span
          v-for="selectedComponentName in selectedComponentNames"
          :key="selectedComponentName"
          >{{ selectedComponentName }}</span
        >
      </gl-intersperse>
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoadingComponents" size="sm" />
      <template v-else>
        <gl-filtered-search-suggestion
          v-for="component in filteredComponents"
          :key="component.id"
          :value="component"
        >
          <div class="gl-flex gl-items-center">
            <gl-icon
              v-if="config.multiSelect"
              name="check"
              class="gl-mr-3 gl-shrink-0 gl-text-gray-700"
              :class="{
                'gl-invisible': !selectedComponentNames.includes(component.name),
              }"
            />
            {{ component.name }}
          </div>
        </gl-filtered-search-suggestion>
      </template>
    </template>
  </gl-filtered-search-token>
</template>
