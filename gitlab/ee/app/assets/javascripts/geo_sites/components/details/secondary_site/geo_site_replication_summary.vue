<script>
import { GlCard } from '@gitlab/ui';
import { s__ } from '~/locale';
import GeoSiteDatabaseConnectionType from './geo_site_database_connection_type.vue';
import GeoSiteReplicationCounts from './geo_site_replication_counts.vue';
import GeoSiteReplicationStatus from './geo_site_replication_status.vue';
import GeoSiteSyncSettings from './geo_site_sync_settings.vue';

export default {
  name: 'GeoSiteReplicationSummary',
  i18n: {
    databaseConnectionType: s__('Geo|Database Connection Type'),
    replicationSummary: s__('Geo|Replication summary'),
    replicationStatus: s__('Geo|Database Replication status'),
    syncSettings: s__('Geo|Synchronization settings'),
  },
  components: {
    GlCard,
    GeoSiteDatabaseConnectionType,
    GeoSiteReplicationStatus,
    GeoSiteSyncSettings,
    GeoSiteReplicationCounts,
  },
  props: {
    site: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <h5 class="gl-my-0">{{ $options.i18n.replicationSummary }}</h5>
    </template>
    <div class="gl-mb-5 gl-flex gl-flex-col">
      <span>{{ $options.i18n.replicationStatus }}</span>
      <geo-site-replication-status class="gl-mt-3" :site="site" />
    </div>
    <div class="gl-mb-5 gl-flex gl-flex-col">
      <span>{{ $options.i18n.databaseConnectionType }}</span>
      <geo-site-database-connection-type class="gl-mt-3" :site="site" />
    </div>
    <div class="gl-mb-5 gl-flex gl-flex-col">
      <span>{{ $options.i18n.syncSettings }}</span>
      <geo-site-sync-settings class="gl-mt-2" :site="site" />
    </div>
    <geo-site-replication-counts :site-id="site.id" class="gl-mb-5" />
  </gl-card>
</template>
