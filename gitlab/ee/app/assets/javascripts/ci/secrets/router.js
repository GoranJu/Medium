import Vue from 'vue';
import VueRouter from 'vue-router';
import { __, s__ } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import {
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  ENTITY_GROUP,
  ENTITY_PROJECT,
  INDEX_ROUTE_NAME,
  NEW_ROUTE_NAME,
} from './constants';
import SecretDetailsWrapper from './components/secret_details/secret_details_wrapper.vue';
import SecretFormWrapper from './components/secret_form/secret_form_wrapper.vue';
import SecretsTable from './components/secrets_table/secrets_table.vue';

Vue.use(VueRouter);

export const initNavigationGuards = ({ router, base, props, location }) => {
  if (location.includes(base)) {
    // any navigation to the index route redirects
    // to CI/CD settings with the secrets section expanded
    router.beforeEach((to, _, next) => {
      if (to.name === INDEX_ROUTE_NAME) {
        visitUrl(props.projectSecretsSettingsPath);
      } else next();
    });
  } else {
    // any navigation away from the index route redirects
    // to the requested route within the main /-/secrets app
    router.beforeEach((to, _, next) => {
      if (to.name !== INDEX_ROUTE_NAME) {
        visitUrl(base + to.fullPath);
      } else next();
    });
  }
  return router;
};

export default (base, props, location) => {
  const { groupPath, projectPath } = props;

  const entity = projectPath ? ENTITY_PROJECT : ENTITY_GROUP;
  const fullPath = projectPath || groupPath;
  const isGroup = entity === ENTITY_GROUP;

  // in the main /-/secrets app, use normal router (history)
  // in CI/CD settings, suppress URL changes (abstract)
  const mode = location?.includes(base) ? 'history' : 'abstract';

  const router = new VueRouter({
    mode,
    base,
    routes: [
      {
        name: INDEX_ROUTE_NAME,
        path: '/',
        component: SecretsTable,
        props: () => {
          return { isGroup, fullPath };
        },
        meta: {
          getBreadcrumbText: () => s__('Secrets|Secrets'),
          isRoot: true,
        },
      },
      {
        name: NEW_ROUTE_NAME,
        path: '/new',
        component: SecretFormWrapper,
        props: () => {
          return { entity, fullPath };
        },
        meta: {
          getBreadcrumbText: () => s__('Secrets|New secret'),
        },
      },
      {
        name: DETAILS_ROUTE_NAME,
        path: '/:secretName/details',
        component: SecretDetailsWrapper,
        props: ({ params: { secretName }, name }) => {
          return { fullPath, secretName, routeName: name };
        },
        meta: {
          getBreadcrumbText: ({ id }) => id,
          isDetails: true,
        },
      },
      {
        name: EDIT_ROUTE_NAME,
        path: '/:secretName/edit',
        component: SecretFormWrapper,
        props: ({ params: { secretName } }) => {
          return {
            entity,
            fullPath,
            isEditing: true,
            secretName,
          };
        },
        meta: {
          getBreadcrumbText: () => __('Edit'),
        },
      },
      {
        path: '/:id',
        redirect: '/:id/details',
      },
      {
        path: '*',
        redirect: '/',
      },
    ],
  });

  // in abstract mode, we have to tell the router where to start
  if (mode === 'abstract') {
    router.push('/');
  }

  return router;
};
