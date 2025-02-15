<script>
import { s__, n__, sprintf, __ } from '~/locale';
import ToggleList from './toggle_list.vue';

export default {
  name: 'ProjectsToggleList',
  components: {
    ToggleList,
  },
  i18n: {
    allProjectsText: s__(
      'SecurityOrchestration|%{allLabel}%{projectCount} %{projectLabel} in this group',
    ),
    allProjectsExceptText: s__('SecurityOrchestration|All projects in this group except:'),
    allProjectsForProjectExceptText: s__(
      'SecurityOrchestration|All projects linked to this project except:',
    ),
    allProjectsButtonText: s__('SecurityOrchestration|Show all included projects'),
    hideProjectsButtonText: s__('SecurityOrchestration|Hide extra projects'),
    showMoreProjectsLabel: s__('SecurityOrchestration|Show more projects'),
    hideMoreProjectsLabel: s__('SecurityOrchestration|Hide extra projects'),
    allLabel: __('All'),
    projectsLabel: __('projects'),
  },
  props: {
    projects: {
      type: Array,
      required: false,
      default: () => [],
    },
    including: {
      type: Boolean,
      required: false,
      default: false,
    },
    projectsToShow: {
      type: Number,
      required: false,
      default: 0,
    },
    bulletStyle: {
      type: Boolean,
      required: false,
      default: true,
    },
    inlineList: {
      type: Boolean,
      required: false,
      default: false,
    },
    isGroup: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    allProjects() {
      return !this.including && this.projects.length === 0;
    },
    allProjectsExcept() {
      return !this.including && this.projects.length > 0;
    },
    customButtonText() {
      return this.allProjects ? this.$options.i18n.allProjectsButtonText : null;
    },
    projectIncludingText() {
      const projects = n__('project', 'projects', this.projects.length);
      return sprintf(__('%{projectLength} %{projects}:'), {
        projectLength: this.projects.length,
        projects,
      });
    },
    header() {
      if (this.allProjects) {
        return this.renderHeader(this.$options.i18n.allProjectsText);
      }

      if (this.allProjectsExcept) {
        const { allProjectsExceptText, allProjectsForProjectExceptText } = this.$options.i18n;
        return this.isGroup ? allProjectsExceptText : allProjectsForProjectExceptText;
      }

      return this.projectIncludingText;
    },
    projectNames() {
      return this.projects.map(({ name }) => name);
    },
  },
  methods: {
    renderHeader(message) {
      const projectLength = this.projects.length;
      const projectLabel = n__('project', 'projects', projectLength);

      return sprintf(message, {
        allLabel: projectLength === 0 ? this.$options.i18n.allLabel : '',
        projectCount: projectLength > 0 ? ` ${projectLength}` : '',
        projectLabel,
      }).trim();
    },
  },
};
</script>

<template>
  <div>
    <p class="gl-mb-2" data-testid="toggle-list-header">{{ header }}</p>

    <toggle-list
      v-if="projects.length"
      :bullet-style="bulletStyle"
      :custom-button-text="$options.i18n.showMoreProjectsLabel"
      :custom-close-button-text="$options.i18n.hideMoreProjectsLabel"
      :inline-list="inlineList"
      :default-button-text="customButtonText"
      :default-close-button-text="$options.i18n.hideProjectsButtonText"
      :items="projectNames"
      :items-to-show="projectsToShow"
    />
  </div>
</template>
