import Vue from 'vue';
import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import DependenciesApp from './components/app.vue';
import createStore from './store';
import apolloProvider from './graphql/provider';
import { NAMESPACE_GROUP } from './constants';

export default (namespaceType) => {
  const el = document.querySelector('#js-dependencies-app');

  const {
    hasDependencies,
    emptyStateSvgPath,
    documentationPath,
    endpoint,
    licensesEndpoint,
    exportEndpoint,
    vulnerabilitiesEndpoint,
    locationsEndpoint,
    belowGroupLimit,
    pageInfo,
    sbomReportsErrors,
    latestSuccessfulScanPath,
    scanFinishedAt,
    groupFullPath,
    projectFullPath,
  } = el.dataset;

  const store = createStore();

  const provide = {
    hasDependencies: parseBoolean(hasDependencies),
    emptyStateSvgPath,
    documentationPath,
    endpoint,
    licensesEndpoint,
    exportEndpoint,
    vulnerabilitiesEndpoint,
    namespaceType,
    pageInfo: pageInfo ? convertObjectPropsToCamelCase(JSON.parse(pageInfo)) : {},
    belowGroupLimit: parseBoolean(belowGroupLimit),
    latestSuccessfulScanPath,
    scanFinishedAt,
    groupFullPath,
    projectFullPath,
  };

  if (namespaceType === NAMESPACE_GROUP) {
    provide.locationsEndpoint = locationsEndpoint;
  }

  const props = {
    sbomReportsErrors: sbomReportsErrors ? JSON.parse(sbomReportsErrors) : [],
  };

  return new Vue({
    el,
    name: 'DependenciesAppRoot',
    components: {
      DependenciesApp,
    },
    store,
    apolloProvider,
    provide,
    render(createElement) {
      return createElement(DependenciesApp, {
        props,
      });
    },
  });
};
