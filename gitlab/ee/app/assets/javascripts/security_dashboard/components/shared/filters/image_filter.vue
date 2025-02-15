<script>
import { GlCollapsibleListbox, GlTruncate } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import agentImagesQuery from 'ee/security_dashboard/graphql/queries/agent_images.query.graphql';
import projectImagesQuery from 'ee/security_dashboard/graphql/queries/project_images.query.graphql';
import { DASHBOARD_TYPE_PROJECT } from 'ee/security_dashboard/constants';
import QuerystringSync from './querystring_sync.vue';
import { ALL_ID } from './constants';

export default {
  components: {
    GlCollapsibleListbox,
    GlTruncate,
    QuerystringSync,
  },
  apollo: {
    images: {
      query() {
        return this.isAgentDashboard ? agentImagesQuery : projectImagesQuery;
      },
      variables() {
        return {
          agentName: this.agentName,
          projectPath: this.projectFullPath || this.fullPath,
        };
      },
      update(data) {
        const vulnerabilityImages = this.isAgentDashboard
          ? data.project?.clusterAgent?.vulnerabilityImages
          : data.project?.vulnerabilityImages;

        return vulnerabilityImages.nodes.map(({ name }) => ({ text: name, value: name, id: name }));
      },
      error() {
        createAlert({ message: this.$options.i18n.loadingError });
      },
    },
  },
  inject: {
    agentName: { default: '' },
    dashboardType: { default: DASHBOARD_TYPE_PROJECT },
    fullPath: { default: '' },
    projectFullPath: { default: '' },
  },
  data: () => ({
    images: [],
    selected: [],
  }),
  computed: {
    isAgentDashboard() {
      return this.dashboardType === DASHBOARD_TYPE_PROJECT && Boolean(this.agentName);
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.images,
        selected: this.selected,
        placeholder: this.$options.i18n.allItemsText,
      });
    },
    isLoading() {
      return this.$apollo.queries.images.loading;
    },
    items() {
      return [
        {
          text: this.$options.i18n.allItemsText,
          value: ALL_ID,
        },
        ...this.images,
      ];
    },
    selectedItems() {
      return !this.selected.length ? [ALL_ID] : this.selected;
    },
  },
  watch: {
    selected() {
      this.$emit('filter-changed', { image: this.selected });
    },
  },
  methods: {
    updateSelected(selected) {
      if (selected?.at(-1) === ALL_ID) {
        this.selected = [];
      } else {
        this.selected = selected.filter((value) => value !== ALL_ID);
      }
    },
  },
  i18n: {
    label: s__('SecurityReports|Image'),
    allItemsText: s__('SecurityReports|All images'),
    loadingError: s__('SecurityOrchestration|Failed to load images.'),
  },
  ALL_ID,
};
</script>

<template>
  <div>
    <querystring-sync v-model="selected" querystring-key="image" />
    <label class="gl-mb-2">{{ $options.i18n.label }}</label>
    <gl-collapsible-listbox
      :selected="selectedItems"
      :items="items"
      :toggle-text="toggleText"
      :header-text="$options.i18n.label"
      :loading="isLoading"
      fluid-width
      multiple
      block
      @select="updateSelected"
    >
      <template #list-item="{ item }">
        <gl-truncate position="middle" :text="item.text" />
      </template>
    </gl-collapsible-listbox>
  </div>
</template>
