import Vue from 'vue';
import GeoReplicableItemApp from './components/app.vue';

export const initGeoReplicableItem = () => {
  const el = document.getElementById('js-geo-replicable-item');
  const { replicableItemId, graphqlFieldName } = el.dataset;

  return new Vue({
    el,
    render(createElement) {
      return createElement(GeoReplicableItemApp, {
        props: {
          replicableItemId,
          graphqlFieldName,
        },
      });
    },
  });
};
