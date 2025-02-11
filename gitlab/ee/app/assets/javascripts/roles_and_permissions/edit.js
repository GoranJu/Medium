import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import CreateMemberRole from './components/create_member_role.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initEditMemberRoleApp = () => {
  const el = document.querySelector('#js-edit-member-role');

  if (!el) {
    return null;
  }

  const { groupFullPath, listPagePath, roleId } = el.dataset;

  return new Vue({
    el,
    name: 'EditMemberRoleRoot',
    apolloProvider,
    render(createElement) {
      return createElement(CreateMemberRole, {
        props: {
          groupFullPath,
          listPagePath,
          roleId: Number(roleId),
        },
      });
    },
  });
};
