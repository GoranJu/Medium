import VueApollo from 'vue-apollo';
import { __ } from '~/locale';
import createDefaultClient from '~/lib/graphql';
import { GROUP_VIEW_TYPE, PROJECT_VIEW_TYPE } from '~/usage_quotas/constants';
import GroupTransferApp from './components/group_transfer_app.vue';
import ProjectTransferApp from './components/project_transfer_app.vue';

const parseProvideData = (el) => {
  const { fullPath } = el.dataset;
  return {
    fullPath,
  };
};

const getViewComponent = (viewType) => {
  if (viewType === GROUP_VIEW_TYPE) {
    return GroupTransferApp;
  }

  if (viewType === PROJECT_VIEW_TYPE) {
    return ProjectTransferApp;
  }

  return {};
};

export const getTransferTabMetadata = ({ viewType = null, includeEl = false } = {}) => {
  const el = document.querySelector('#js-transfer-usage-app');
  const vueComponent = getViewComponent(viewType);

  if (!el || !vueComponent) return false;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const transferTabMetadata = {
    title: __('Transfer'),
    hash: '#transfer-quota-tab',
    testid: 'transfer-tab',
    component: {
      name: 'TransferTab',
      apolloProvider,
      provide: parseProvideData(el),
      render(createElement) {
        return createElement(vueComponent);
      },
    },
  };
  if (includeEl) {
    transferTabMetadata.component.el = el;
  }

  return transferTabMetadata;
};
