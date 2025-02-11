import { __ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from '../shared/provider';
import PagesDeploymentsApp from './components/app.vue';

export const parseProvideData = (el) => {
  const {
    fullPath,
    deploymentsLimit,
    deploymentsCount,
    projectDeploymentsCount,
    deploymentsByProject,
    domain,
    usesNamespaceDomain,
  } = el.dataset;

  return {
    fullPath,
    deploymentsLimit: parseInt(deploymentsLimit, 10),
    deploymentsCount: parseInt(deploymentsCount, 10),
    projectDeploymentsCount: parseInt(projectDeploymentsCount, 10),
    deploymentsByProject: deploymentsByProject ? JSON.parse(deploymentsByProject) : [],
    domain,
    usesNamespaceDomain: parseBoolean(usesNamespaceDomain),
  };
};

export const getPagesTabMetadata = ({ viewType } = {}) => {
  const el = document.querySelector('#js-pages-deployments-app');

  if (!el) return false;

  return {
    title: __('Pages'),
    hash: '#pages-deployments-usage-tab',
    testid: 'pages-tab',
    component: {
      name: 'PagesDeploymentsTab',
      apolloProvider,
      provide: {
        viewType,
        ...parseProvideData(el),
      },
      render(createElement) {
        return createElement(PagesDeploymentsApp);
      },
    },
  };
};
