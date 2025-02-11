import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { resolvers, cacheConfig } from './graphql/settings';
import getSecretsQuery from './graphql/queries/client/get_secrets.query.graphql';

import createRouter, { initNavigationGuards } from './router';

import SecretsApp from './components/secrets_app.vue';
import SecretsBreadcrumbs from './components/secrets_breadcrumbs.vue';
import { mockGroupSecretsData, mockProjectSecretsData } from './mock_data';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(resolvers, { cacheConfig }),
});

// eslint-disable-next-line max-params
const initSecretsApp = (el, app, props, basePath) => {
  const router = createRouter(basePath, props, window.location.href);

  if (window.location.href.includes(basePath)) {
    injectVueAppBreadcrumbs(router, SecretsBreadcrumbs);
  }

  initNavigationGuards({ router, base: basePath, props, location: window.location.href });

  return new Vue({
    el,
    router,
    name: 'SecretsRoot',
    apolloProvider,
    render(createElement) {
      return createElement(app, { props });
    },
  });
};

export const initGroupSecretsApp = () => {
  const el = document.querySelector('#js-group-secrets-manager');

  if (!el) {
    return false;
  }

  const { groupPath, groupId, basePath } = el.dataset;

  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: getSecretsQuery,
    variables: { fullPath: groupPath, isGroup: true },
    data: {
      group: {
        id: convertToGraphQLId(TYPENAME_GROUP, groupId),
        fullPath: groupPath,
        secrets: {
          count: mockGroupSecretsData.length,
          nodes: mockGroupSecretsData,
        },
      },
    },
  });

  return initSecretsApp(el, SecretsApp, { groupPath, groupId }, basePath);
};

export const initProjectSecretsApp = () => {
  const el = document.querySelector('#js-project-secrets-manager');

  if (!el) {
    return false;
  }

  const { projectPath, projectSecretsSettingsPath, projectId, basePath } = el.dataset;

  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: getSecretsQuery,
    variables: { fullPath: projectPath, isProject: true },
    data: {
      project: {
        id: convertToGraphQLId(TYPENAME_PROJECT, projectId),
        fullPath: projectPath,
        secrets: {
          count: mockProjectSecretsData.length,
          nodes: mockProjectSecretsData,
        },
      },
    },
  });

  return initSecretsApp(
    el,
    SecretsApp,
    { projectPath, projectSecretsSettingsPath, projectId },
    basePath,
  );
};
