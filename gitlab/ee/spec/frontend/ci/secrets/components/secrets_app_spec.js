import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretsApp from 'ee/ci/secrets/components/secrets_app.vue';

describe('SecretsApp', () => {
  let wrapper;

  const groupProps = { groupPath: '/path/to/group', groupId: '123' };
  const projectProps = { projectPath: '/path/to/project', projectId: '123' };

  Vue.use(VueRouter);
  Vue.use(VueApollo);

  const findRouterView = () => wrapper.findComponent({ ref: 'router-view' });

  const createComponent = (props) => {
    wrapper = shallowMountExtended(SecretsApp, { propsData: { ...props } });
  };

  describe.each`
    entity       | props
    ${'group'}   | ${groupProps}
    ${'project'} | ${projectProps}
  `('$entity secrets app', ({ props }) => {
    it('renders the secrets app', () => {
      createComponent(props);

      expect(wrapper.findComponent(SecretsApp).exists()).toBe(true);
    });

    it('renders the router view', () => {
      createComponent(props);

      expect(findRouterView().exists()).toBe(true);
    });
  });
});
