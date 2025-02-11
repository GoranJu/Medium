import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import { buildCycleAnalyticsInitialData } from 'ee/analytics/shared/utils';
import createStore from '../store';
import VSASettingsApp from './components/app.vue';

export default () => {
  const el = document.getElementById('js-vsa-settings-app');
  if (!el) return false;

  const { isEditPage, vsaPath } = el.dataset;
  const initialData = buildCycleAnalyticsInitialData(el.dataset);
  const store = createStore();

  store.dispatch('initializeCycleAnalytics', initialData);

  return new Vue({
    el,
    store,
    provide: {
      vsaPath,
    },
    render: (createElement) =>
      createElement(VSASettingsApp, {
        props: {
          isEditing: parseBoolean(isEditPage),
        },
      }),
  });
};
