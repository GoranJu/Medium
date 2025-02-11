import VueRouter from 'vue-router';

import { joinPaths } from '~/lib/utils/url_utility';

import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
  ROUTE_NEW_FRAMEWORK,
  ROUTE_EDIT_FRAMEWORK,
  ROUTE_NEW_FRAMEWORK_SUCCESS,
  ROUTE_EXPORT_FRAMEWORK,
} from './constants';

import MainLayout from './components/main_layout.vue';

import ViolationsReport from './components/violations_report/report.vue';
import FrameworksReport from './components/frameworks_report/report.vue';
import EditFramework from './components/frameworks_report/edit_framework/edit_framework.vue';
import ProjectsReport from './components/projects_report/report.vue';
import StandardsReport from './components/standards_adherence_report/report.vue';
import NewFrameworkSuccess from './components/frameworks_report/edit_framework/new_framework_success.vue';

export function createRouter(basePath, props) {
  const {
    mergeCommitsCsvExportPath,
    groupPath,
    projectPath,
    rootAncestorPath,
    rootAncestorName,
    rootAncestorComplianceCenterPath,
    routes: availableRoutes,
  } = props;

  const availableTabRoutes = [
    {
      path: 'standards_adherence',
      name: ROUTE_STANDARDS_ADHERENCE,
      component: StandardsReport,
      props: {
        groupPath,
        projectPath,
        rootAncestorPath,
      },
    },
    {
      path: 'violations',
      name: ROUTE_VIOLATIONS,
      component: ViolationsReport,
      props: {
        mergeCommitsCsvExportPath,
        groupPath,
        projectPath,
      },
    },
    {
      path: 'frameworks',
      name: ROUTE_FRAMEWORKS,
      component: FrameworksReport,
      props: {
        groupPath,
        projectPath,
        rootAncestor: {
          path: rootAncestorPath,
          name: rootAncestorName,
          complianceCenterPath: rootAncestorComplianceCenterPath,
        },
      },
    },
    {
      path: '/projects',
      name: ROUTE_PROJECTS,
      component: ProjectsReport,
      props: {
        groupPath,
        rootAncestor: {
          path: rootAncestorPath,
          name: rootAncestorName,
          complianceCenterPath: rootAncestorComplianceCenterPath,
        },
      },
    },
  ].filter(({ name }) => availableRoutes.includes(name));

  const defaultRoute = availableTabRoutes[0].name;

  const routes = [
    {
      path: '/frameworks/new',
      name: ROUTE_NEW_FRAMEWORK,
      component: EditFramework,
    },
    {
      path: '/frameworks/new/success',
      name: ROUTE_NEW_FRAMEWORK_SUCCESS,
      component: NewFrameworkSuccess,
    },
    {
      path: '/frameworks/:id',
      name: ROUTE_EDIT_FRAMEWORK,
      component: EditFramework,
    },
    {
      path: '/',
      component: MainLayout,
      props: {
        availableTabs: availableRoutes,
        groupPath,
        rootAncestor: {
          path: rootAncestorPath,
          name: rootAncestorName,
          complianceCenterPath: rootAncestorComplianceCenterPath,
        },
      },
      children: [...availableTabRoutes, { path: '*', redirect: { name: defaultRoute } }],
    },
    {
      name: ROUTE_EXPORT_FRAMEWORK,
      path: '/frameworks/:id.json',
    },
  ];

  return new VueRouter({
    mode: 'history',
    base: joinPaths(gon.relative_url_root || '', basePath),
    routes,
  });
}
