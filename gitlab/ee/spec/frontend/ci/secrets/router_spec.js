import Vue from 'vue';
import VueRouter from 'vue-router';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { TEST_HOST } from 'helpers/test_constants';
import { visitUrl } from '~/lib/utils/url_utility';
import SecretDetailsWrapper from 'ee/ci/secrets/components/secret_details/secret_details_wrapper.vue';
import SecretFormWrapper from 'ee/ci/secrets/components/secret_form/secret_form_wrapper.vue';
import SecretsTable from 'ee/ci/secrets/components/secrets_table/secrets_table.vue';
import createRouter, { initNavigationGuards } from 'ee/ci/secrets/router';
import { ENTITY_GROUP } from 'ee/ci/secrets/constants';
import SecretsApp from 'ee//ci/secrets/components/secrets_app.vue';

Vue.use(VueRouter);
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('Secrets router', () => {
  let wrapper;
  let router;

  const base = '/-/secrets';
  const defaultLocation = `${TEST_HOST}${base}`;

  const groupProps = {
    groupId: '1',
    groupPath: '/path/to/group',
  };

  const projectProps = {
    projectId: '2',
    projectPath: '/path/to/project',
    projectSecretsSettingsPath: '/path/to/project/-/settings/ci_cd',
  };

  const editRoute = { name: 'edit', params: { secretName: 'SECRET_KEY' } };

  const createRouterWithNavigationGuards = (basePath, props, location) => {
    router = initNavigationGuards({
      router: createRouter(basePath, props, location),
      base: basePath,
      props,
      location,
    });
  };

  const createSecretsApp = ({ route, props, location = defaultLocation } = {}) => {
    router = createRouter(base, props, location);
    if (route) {
      router.push(route);
    }

    wrapper = mountExtended(SecretsApp, {
      router,
      propsData: { ...props },
      data() {
        return {
          secrets: [],
        };
      },
      mocks: {
        $apollo: {
          queries: {
            environments: { loading: true },
            secrets: { loading: false },
          },
        },
      },
    });
  };

  it.each`
    path                     | componentNames            | components
    ${'/'}                   | ${'SecretsTable'}         | ${[SecretsTable]}
    ${'/?page=2'}            | ${'SecretsTable'}         | ${[SecretsTable]}
    ${'/new'}                | ${'SecretFormWrapper'}    | ${[SecretFormWrapper]}
    ${'/secretName/details'} | ${'SecretDetailsWrapper'} | ${[SecretDetailsWrapper]}
    ${'/secretName/edit'}    | ${'SecretFormWrapper'}    | ${[SecretFormWrapper]}
  `('uses $componentNames for path "$path"', ({ path, components }) => {
    router = createRouter(base, groupProps, defaultLocation);

    expect(router.getMatchedComponents(path)).toStrictEqual(components);
  });

  it.each`
    path                          | redirect
    ${'/secretName'}              | ${'/secretName/details'}
    ${'/secretName/unknownroute'} | ${'/'}
  `('redirects from $path to $redirect', async ({ path, redirect }) => {
    router = createRouter(base, groupProps, defaultLocation);

    await router.push(path);

    expect(router.currentRoute.path).toBe(redirect);
  });

  describe.each`
    entity       | props           | fullPath
    ${'group'}   | ${groupProps}   | ${groupProps.groupPath}
    ${'project'} | ${projectProps} | ${projectProps.projectPath}
  `('$entity secrets form', ({ entity, props, fullPath }) => {
    it('provides the correct props when visiting the index', () => {
      createSecretsApp({ route: '/', props, location: defaultLocation });

      expect(wrapper.findComponent(SecretsTable).props()).toMatchObject({
        isGroup: entity === ENTITY_GROUP,
        fullPath,
      });
    });

    it('provides the correct props when visiting the create form', () => {
      createSecretsApp({ route: '/new', props, location: defaultLocation });

      expect(wrapper.findComponent(SecretFormWrapper).props()).toMatchObject({
        entity,
        fullPath,
      });
    });

    it('provides the correct props when visiting the edit form', () => {
      createSecretsApp({ route: editRoute, props, location: defaultLocation });

      expect(wrapper.findComponent(SecretFormWrapper).props()).toMatchObject({
        entity,
        fullPath,
        isEditing: true,
        secretName: 'SECRET_KEY',
      });
    });
  });

  describe('navigation guards', () => {
    const secretsBase = '/path/to/project/-/secrets';
    const settingsLocation = `${TEST_HOST}/path/to/project/-/settings/ci_cd`;
    const secretsLocation = `${TEST_HOST}${secretsBase}`;

    describe('on /-/settings/ci_cd', () => {
      beforeEach(() => {
        createRouterWithNavigationGuards(secretsBase, projectProps, settingsLocation);
      });

      it('navigating within the index route does not redirect', () => {
        router.push('/?page=2');

        expect(visitUrl).not.toHaveBeenCalled();
      });

      it.each([editRoute, '/new', '/secretName/details', '/secretName/edit'])(
        'navigating to the non-index route %s redirects to the appropriate route in /-/secrets',
        (route) => {
          router.push(route);

          expect(visitUrl).toHaveBeenCalledWith(expect.stringContaining(secretsBase));
        },
      );
    });

    describe('on /-/secrets', () => {
      beforeEach(() => {
        createRouterWithNavigationGuards(secretsBase, projectProps, secretsLocation);
      });

      it.each([editRoute, '/new', '/secretName/details', '/secretName/edit'])(
        'navigating to the non-index route %s does not redirect',
        (route) => {
          router.push(route);

          expect(visitUrl).not.toHaveBeenCalled();
        },
      );

      it('navigating to the index route redirects to /-/settings/ci_cd', () => {
        router.push('/');

        expect(visitUrl).toHaveBeenCalledWith('/path/to/project/-/settings/ci_cd');
      });
    });
  });
});
