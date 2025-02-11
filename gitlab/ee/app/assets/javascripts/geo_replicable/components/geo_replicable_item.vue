<script>
import { GlButton, GlLink, GlSprintf } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { __, s__ } from '~/locale';
import { ACTION_TYPES } from '../constants';
import GeoReplicableStatus from './geo_replicable_status.vue';
import GeoReplicableTimeAgo from './geo_replicable_time_ago.vue';

export default {
  name: 'GeoReplicableItem',
  i18n: {
    unknown: __('Unknown'),
    nA: __('Not applicable.'),
    resync: s__('Geo|Resync'),
    reverify: s__('Geo|Reverify'),
    lastVerified: s__('Geo|Last time verified'),
    modelRecordId: s__('Geo|Model record: %{modelRecordId}'),
  },
  components: {
    GlButton,
    GlLink,
    GeoReplicableTimeAgo,
    GeoReplicableStatus,
    GlSprintf,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['replicableBasePath'],
  props: {
    name: {
      type: String,
      required: true,
    },
    registryId: {
      type: [String, Number],
      required: true,
    },
    modelRecordId: {
      type: Number,
      required: true,
    },
    syncStatus: {
      type: String,
      required: false,
      default: '',
    },
    lastSynced: {
      type: String,
      required: false,
      default: '',
    },
    lastVerified: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    ...mapState(['verificationEnabled']),
    timeAgoArray() {
      return [
        {
          label: capitalizeFirstCharacter(this.syncStatus),
          dateString: this.lastSynced,
          defaultText: this.$options.i18n.unknown,
        },
        {
          label: this.$options.i18n.lastVerified,
          dateString: this.lastVerified,
          defaultText: this.verificationEnabled
            ? this.$options.i18n.unknown
            : this.$options.i18n.nA,
        },
      ];
    },
    detailsPath() {
      return `${this.replicableBasePath}/${getIdFromGraphQLId(this.registryId)}`;
    },
  },
  methods: {
    ...mapActions(['initiateReplicableAction']),
  },
  actionTypes: ACTION_TYPES,
};
</script>

<template>
  <div class="gl-border-b gl-p-5">
    <div
      class="geo-replicable-item-grid gl-grid gl-items-center gl-pb-4"
      data-testid="replicable-item-header"
    >
      <geo-replicable-status :status="syncStatus" />

      <gl-link v-if="glFeatures.geoReplicablesShowView" class="gl-font-bold" :href="detailsPath">{{
        name
      }}</gl-link>
      <span v-else class="gl-font-bold">{{ name }}</span>

      <div>
        <gl-button
          data-testid="geo-resync-item"
          size="small"
          @click="
            initiateReplicableAction({ registryId, name, action: $options.actionTypes.RESYNC })
          "
        >
          {{ $options.i18n.resync }}
        </gl-button>
        <gl-button
          v-if="verificationEnabled"
          data-testid="geo-reverify-item"
          size="small"
          @click="
            initiateReplicableAction({ registryId, name, action: $options.actionTypes.REVERIFY })
          "
        >
          {{ $options.i18n.reverify }}
        </gl-button>
      </div>
    </div>
    <div class="gl-flex gl-flex-wrap gl-items-center">
      <span class="gl-border-r-1 gl-px-2 gl-text-sm gl-text-subtle gl-border-r-solid">
        <gl-sprintf :message="$options.i18n.modelRecordId">
          <template #modelRecordId>
            {{ modelRecordId }}
          </template>
        </gl-sprintf>
      </span>

      <geo-replicable-time-ago
        v-for="(timeAgo, index) in timeAgoArray"
        :key="index"
        :label="timeAgo.label"
        :date-string="timeAgo.dateString"
        :default-text="timeAgo.defaultText"
        :show-divider="index !== timeAgoArray.length - 1"
      />
    </div>
  </div>
</template>
