<script>
import { GlLink, GlLoadingIcon, GlTable, GlIcon, GlSprintf } from '@gitlab/ui';
import VisibilityIconButton from '~/vue_shared/components/visibility_icon_button.vue';

import { ROUTE_PROJECTS } from 'ee/compliance_dashboard/constants';
import { i18n } from '../constants';

import EditSection from './edit_section.vue';

export default {
  components: {
    EditSection,

    GlLink,
    GlLoadingIcon,
    GlTable,
    GlIcon,
    GlSprintf,
    VisibilityIconButton,
  },
  props: {
    complianceFramework: {
      type: Object,
      required: true,
    },
  },
  computed: {
    projects() {
      return this.complianceFramework?.projects?.nodes;
    },
  },
  tableFields: [
    {
      key: 'name',
      label: i18n.projectsTableFields.name,
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-white !gl-border-b-white',
    },
    {
      key: 'subgroup',
      label: i18n.projectsTableFields.subgroup,
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-white !gl-border-b-white',
    },
    {
      key: 'description',
      label: i18n.projectsTableFields.description,
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-white !gl-border-b-white',
    },
  ],
  i18n,
  ROUTE_PROJECTS,
};
</script>
<template>
  <edit-section
    :title="$options.i18n.projects"
    :description="$options.i18n.projectsDescription"
    :items-count="projects.length"
  >
    <gl-table
      v-if="projects.length"
      ref="projectsTable"
      class="gl-mb-6"
      :items="projects"
      :fields="$options.tableFields"
      responsive
      stacked="md"
      hover
      select-mode="single"
      selected-variant="primary"
    >
      <template #cell(name)="{ item }">
        <gl-link data-testid="project-link" :href="item.webUrl">{{ item.name }}</gl-link>
        <visibility-icon-button
          v-if="item.visibility"
          class="gl-ml-2"
          :visibility-level="item.visibility"
        />
      </template>
      <template #cell(subgroup)="{ item }">
        <gl-link v-if="item.namespace" data-testid="subgroup-link" :href="item.namespace.webUrl">
          {{ item.namespace.fullName }}
        </gl-link>
      </template>
      <template #cell(description)="{ item }">
        {{ item.description }}
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" />
      </template>
    </gl-table>
    <div class="gl-ml-5" data-testid="info-text">
      <gl-icon name="information-o" variant="subtle" class="gl-mr-2" />
      <gl-sprintf data-testid="info-text" :message="$options.i18n.projectsInfoText">
        <template #link="{ content }">
          <gl-link :to="`/${$options.ROUTE_PROJECTS}`">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </div>
  </edit-section>
</template>
