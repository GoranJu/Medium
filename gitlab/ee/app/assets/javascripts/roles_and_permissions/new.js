import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import CreateMemberRole from './components/create_member_role.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initCreateMemberRoleApp = () => {
  const el = document.querySelector('#js-create-member-role');

  if (!el) {
    return null;
  }

  const { groupFullPath, listPagePath } = el.dataset;

  return new Vue({
    el,
    name: 'CreateMemberRoleRoot',
    apolloProvider,
    render(createElement) {
      return createElement(CreateMemberRole, {
        props: { groupFullPath, listPagePath },
      });
    },
  });
};
