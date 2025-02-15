<script>
import {
  GlTab,
  GlTabs,
  GlTooltipDirective,
  GlButton,
  GlTooltip,
  GlSprintf,
  GlLink,
} from '@gitlab/ui';

import PageHeading from '~/vue_shared/components/page_heading.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import Tracking from '~/tracking';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { isTopLevelGroup } from '../utils';

import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
  ROUTE_NEW_FRAMEWORK,
  i18n,
} from '../constants';

import ReportsExport from './shared/export_disclosure_dropdown.vue';

const tabConfigs = {
  [ROUTE_STANDARDS_ADHERENCE]: {
    testId: 'standards-adherence-tab',
    title: i18n.standardsAdherenceTab,
  },
  [ROUTE_VIOLATIONS]: {
    testId: 'violations-tab',
    title: i18n.violationsTab,
  },
  [ROUTE_FRAMEWORKS]: {
    testId: 'frameworks-tab',
    title: i18n.frameworksTab,
  },
  [ROUTE_PROJECTS]: {
    testId: 'projects-tab',
    title: i18n.projectsTab,
  },
};

export default {
  name: 'ComplianceReportsApp',
  components: {
    GlTabs,
    GlTab,
    GlButton,
    GlTooltip,
    GlSprintf,
    GlLink,
    ReportsExport,
    PageHeading,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [Tracking.mixin(), glAbilitiesMixin()],
  inject: [
    'mergeCommitsCsvExportPath',
    'projectFrameworksCsvExportPath',
    'violationsCsvExportPath',
    'adherencesCsvExportPath',
    'frameworksCsvExportPath',
  ],
  props: {
    availableTabs: {
      type: Array,
      required: true,
    },
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isTopLevelGroup() {
      return isTopLevelGroup(this.groupPath, this.rootAncestor.path);
    },
    hasAtLeastOneExportAvailable() {
      return (
        this.projectFrameworksCsvExportPath ||
        this.mergeCommitsCsvExportPath ||
        this.violationsCsvExportPath ||
        this.adherencesCsvExportPath ||
        this.frameworksCsvExportPath
      );
    },
    tabs() {
      return this.availableTabs.map((tabName) => {
        const tabConfig = tabConfigs[tabName];
        return {
          title: tabConfig.title,
          titleAttributes: { 'data-testid': tabConfig.testId },
          target: tabName,
          // eslint-disable-next-line @gitlab/require-i18n-strings
          contentTestId: `${tabConfig.testId}-content`,
        };
      });
    },
    tabIndex() {
      return this.tabs.findIndex((tab) => tab.target === this.$route.name);
    },
    canAdminComplianceFramework() {
      return this.glAbilities.adminComplianceFramework;
    },
  },
  methods: {
    goTo(name) {
      if (this.$route.name !== name) {
        this.$router.push({ name });

        this.track('click_report_tab', { label: name });
      }
    },
    newFramework() {
      this.$router.push({ name: ROUTE_NEW_FRAMEWORK });
    },
  },
  ROUTE_STANDARDS: ROUTE_STANDARDS_ADHERENCE,
  ROUTE_VIOLATIONS,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  i18n,
  documentationPath: helpPagePath('user/compliance/compliance_center/_index.md'),
};
</script>
<template>
  <div>
    <page-heading :heading="$options.i18n.heading">
      <template #description>
        <gl-sprintf :message="$options.i18n.subheading">
          <template #link="{ content }">
            <gl-link :href="$options.documentationPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
      <template #actions>
        <reports-export
          v-if="hasAtLeastOneExportAvailable"
          :project-frameworks-csv-export-path="projectFrameworksCsvExportPath"
          :merge-commits-csv-export-path="mergeCommitsCsvExportPath"
          :violations-csv-export-path="violationsCsvExportPath"
          :adherences-csv-export-path="adherencesCsvExportPath"
          :frameworks-csv-export-path="frameworksCsvExportPath"
        />
        <gl-tooltip v-if="!isTopLevelGroup" :target="() => $refs.newFrameworkButton">
          <gl-sprintf :message="$options.i18n.newFrameworkButtonMessage">
            <template #link>
              <gl-link :href="rootAncestor.complianceCenterPath">
                {{ rootAncestor.name }}
              </gl-link>
            </template>
          </gl-sprintf>
        </gl-tooltip>
        <span ref="newFrameworkButton">
          <gl-button
            v-if="canAdminComplianceFramework"
            variant="confirm"
            category="secondary"
            :disabled="!isTopLevelGroup"
            @click="newFramework"
            >{{ $options.i18n.newFramework }}</gl-button
          >
        </span>
      </template>
    </page-heading>

    <gl-tabs :value="tabIndex" content-class="gl-p-0" lazy>
      <gl-tab
        v-for="tab in tabs"
        :key="tab.target"
        :title="tab.title"
        :title-link-attributes="tab.titleAttributes"
        :data-testid="tab.contentTestId"
        @click="goTo(tab.target)"
      />
    </gl-tabs>
    <router-view />
  </div>
</template>
