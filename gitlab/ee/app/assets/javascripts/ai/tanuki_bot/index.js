import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import TanukiBotChatApp from './components/app.vue';
import store from './store';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initTanukiBotChatDrawer = () => {
  const el = document.getElementById('js-tanuki-bot-chat-app');

  if (!el) {
    return false;
  }

  const toggleEls = document.querySelectorAll('.js-tanuki-bot-chat-toggle');
  if (toggleEls.length) {
    toggleEls.forEach((toggleEl) => {
      toggleEl.addEventListener('click', () => {
        duoChatGlobalState.isShown = !duoChatGlobalState.isShown;
      });
    });
  }

  const { userId, resourceId, projectId } = el.dataset;

  return new Vue({
    el,
    store,
    apolloProvider,
    render(createElement) {
      return createElement(TanukiBotChatApp, {
        props: {
          userId,
          resourceId,
          projectId,
        },
      });
    },
  });
};
