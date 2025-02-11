import Vue from 'vue';
import { createPinia, PiniaVuePlugin } from 'pinia';
import createRouter from './router';

import app from './service_accounts_app.vue';

import { useServiceAccounts } from './stores/service_accounts';
import { useAccesssTokens } from './stores/access_tokens';

Vue.use(PiniaVuePlugin);

export default (el) => {
  if (!el) {
    return null;
  }

  const { basePath } = el.dataset;

  const pinia = createPinia();
  const router = createRouter(basePath);

  const serviceAccountsStore = useServiceAccounts(pinia);
  const accessTokensStore = useAccesssTokens(pinia);

  return new Vue({
    el,
    name: 'ServiceAccountsRoot',
    router,
    pinia,
    serviceAccountsStore,
    accessTokensStore,
    render(createElement) {
      return createElement(app);
    },
  });
};
