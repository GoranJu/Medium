import Vue from 'vue';
import VueRouter from 'vue-router';

import ServiceAccounts from './components/service_accounts/service_accounts.vue';
import AccessTokens from './components/access_tokens/access_tokens.vue';

Vue.use(VueRouter);

export default (base) => {
  const routes = [
    { path: '/', name: 'service_accounts', component: ServiceAccounts },
    {
      path: '/:id/access_tokens',
      name: 'access_tokens',
      component: AccessTokens,
      props: ({ params: { id } }) => {
        return { serviceAccountId: Number(id) };
      },
    },
  ];

  const router = new VueRouter({
    mode: 'history',
    base,
    routes,
  });

  return router;
};
