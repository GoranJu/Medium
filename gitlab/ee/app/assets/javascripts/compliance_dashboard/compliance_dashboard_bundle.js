import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { createRouter } from './router';
import {
  ROUTE_FRAMEWORKS,
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_VIOLATIONS,
  ROUTE_PROJECTS,
} from './constants';

export default () => {
  const el = document.getElementById('js-compliance-report');

  const {
    basePath,
    mergeCommitsCsvExportPath,
    violationsCsvExportPath,
    projectFrameworksCsvExportPath,
    adherencesCsvExportPath,
    frameworksCsvExportPath,
    groupPath,
    projectPath,
    rootAncestorPath,
    rootAncestorName,
    rootAncestorComplianceCenterPath,
    pipelineConfigurationFullPathEnabled,
    pipelineConfigurationEnabled,
    pipelineExecutionPolicyPath,
    migratePipelineToPolicyPath,
    groupSecurityPoliciesPath,
    disableScanPolicyUpdate,
    featureAdherenceReportEnabled,
    featureViolationsReportEnabled,
    featureProjectsReportEnabled,
    featureSecurityPoliciesEnabled,
    adherenceV2Enabled,
    activeComplianceFrameworks,
  } = el.dataset;

  Vue.use(VueApollo);
  Vue.use(VueRouter);

  const routes = Object.entries({
    [ROUTE_STANDARDS_ADHERENCE]: parseBoolean(featureAdherenceReportEnabled),
    [ROUTE_VIOLATIONS]: parseBoolean(featureViolationsReportEnabled),
    [ROUTE_FRAMEWORKS]: true,
    [ROUTE_PROJECTS]: parseBoolean(featureProjectsReportEnabled),
  })
    .filter(([, status]) => status)
    .map(([route]) => route);

  const router = createRouter(basePath, {
    mergeCommitsCsvExportPath,
    projectPath,
    groupPath,
    rootAncestorPath,
    rootAncestorName,
    rootAncestorComplianceCenterPath,
    routes,
  });

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    apolloProvider,
    name: 'ComplianceReportsApp',
    router,
    provide: {
      namespaceType: projectPath ? 'project' : 'group',
      groupPath,
      rootAncestorPath,
      pipelineConfigurationFullPathEnabled: parseBoolean(pipelineConfigurationFullPathEnabled),
      pipelineConfigurationEnabled: parseBoolean(pipelineConfigurationEnabled),
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      mergeCommitsCsvExportPath,
      violationsCsvExportPath,
      projectFrameworksCsvExportPath,
      adherencesCsvExportPath,
      frameworksCsvExportPath,
      pipelineExecutionPolicyPath,
      migratePipelineToPolicyPath,
      groupSecurityPoliciesPath,
      featureSecurityPoliciesEnabled: parseBoolean(featureSecurityPoliciesEnabled),
      adherenceV2Enabled: parseBoolean(adherenceV2Enabled),
      activeComplianceFrameworks: parseBoolean(activeComplianceFrameworks),
    },

    render: (createElement) => createElement('router-view'),
  });
};
