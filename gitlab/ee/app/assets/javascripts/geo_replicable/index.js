import Vue from 'vue';
import Translate from '~/vue_shared/translate';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import GeoReplicableApp from './components/app.vue';
import createStore from './store';

Vue.use(Translate);

export default () => {
  const el = document.getElementById('js-geo-replicable');
  const { geoReplicableEmptySvgPath, geoCurrentSiteId, geoTargetSiteId, replicableBasePath } =
    el.dataset;

  const { titlePlural, graphqlFieldName, graphqlMutationRegistryClass, verificationEnabled } =
    convertObjectPropsToCamelCase(JSON.parse(el.dataset.replicatorClassData));

  return new Vue({
    el,
    store: createStore({
      titlePlural,
      graphqlFieldName,
      graphqlMutationRegistryClass,
      verificationEnabled,
      geoCurrentSiteId,
      geoTargetSiteId,
    }),
    provide: {
      replicableBasePath,
    },

    render(createElement) {
      return createElement(GeoReplicableApp, {
        props: {
          geoReplicableEmptySvgPath,
        },
      });
    },
  });
};
