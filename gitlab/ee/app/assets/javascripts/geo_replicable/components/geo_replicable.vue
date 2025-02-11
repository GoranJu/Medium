<script>
import { GlKeysetPagination } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { PREV, NEXT } from '../constants';
import GeoReplicableItem from './geo_replicable_item.vue';

export default {
  name: 'GeoReplicable',
  components: {
    GlKeysetPagination,
    GeoReplicableItem,
  },
  computed: {
    ...mapState(['replicableItems', 'paginationData']),
  },
  methods: {
    ...mapActions(['fetchReplicableItems']),
    buildName(item) {
      return item.name ? item.name : item.id;
    },
  },
  NEXT,
  PREV,
};
</script>

<template>
  <section>
    <geo-replicable-item
      v-for="item in replicableItems"
      :key="item.id"
      :name="buildName(item)"
      :registry-id="item.id"
      :model-record-id="item.modelRecordId"
      :sync-status="item.state.toLowerCase()"
      :last-synced="item.lastSyncedAt"
      :last-verified="item.verifiedAt"
    />
    <div class="gl-mt-6 gl-flex gl-justify-center">
      <gl-keyset-pagination
        v-bind="paginationData"
        @next="fetchReplicableItems($options.NEXT)"
        @prev="fetchReplicableItems($options.PREV)"
      />
    </div>
  </section>
</template>
