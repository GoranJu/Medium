<script>
import { GlAlert, GlLoadingIcon, GlDisclosureDropdown } from '@gitlab/ui';
import { createAlert } from '~/alert';
import {
  ADD_STREAM,
  ADD_HTTP,
  ADD_GCP_LOGGING,
  ADD_AMAZON_S3,
  ADD_STREAM_MESSAGE,
  AUDIT_STREAMS_NETWORK_ERRORS,
  DELETE_STREAM_MESSAGE,
  streamsLabel,
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
} from '../constants';
import {
  removeAuditEventsStreamingDestination,
  removeGcpLoggingAuditEventsStreamingDestination,
  removeAmazonS3AuditEventsStreamingDestination,
} from '../graphql/cache_update';
import externalDestinationsQuery from '../graphql/queries/get_external_destinations.query.graphql';
import instanceExternalDestinationsQuery from '../graphql/queries/get_instance_external_destinations.query.graphql';
import gcpLoggingDestinationsQuery from '../graphql/queries/get_google_cloud_logging_destinations.query.graphql';
import instanceGcpLoggingDestinationsQuery from '../graphql/queries/get_instance_google_cloud_logging_destinations.query.graphql';
import amazonS3DestinationsQuery from '../graphql/queries/get_amazon_s3_destinations.query.graphql';
import instanceAmazonS3DestinationsQuery from '../graphql/queries/get_instance_amazon_s3_destinations.query.graphql';
import StreamEmptyState from './stream/stream_empty_state.vue';
import StreamDestinationEditor from './stream/stream_destination_editor.vue';
import StreamGcpLoggingDestinationEditor from './stream/stream_gcp_logging_destination_editor.vue';
import StreamAmazonS3DestinationEditor from './stream/stream_amazon_s3_destination_editor.vue';
import StreamItem from './stream/stream_item.vue';

const { FETCHING_ERROR } = AUDIT_STREAMS_NETWORK_ERRORS;
export default {
  components: {
    GlAlert,
    GlLoadingIcon,
    GlDisclosureDropdown,
    StreamDestinationEditor,
    StreamGcpLoggingDestinationEditor,
    StreamAmazonS3DestinationEditor,
    StreamEmptyState,
    StreamItem,
  },
  inject: ['groupPath'],
  data() {
    return {
      externalAuditEventDestinations: null,
      gcpLoggingAuditEventDestinations: null,
      amazonS3AuditEventDestinations: null,
      isEditorVisible: false,
      successMessage: null,
      editorType: DESTINATION_TYPE_HTTP,
    };
  },
  computed: {
    isLoading() {
      return (
        this.$apollo.queries.externalAuditEventDestinations.loading ||
        this.$apollo.queries.gcpLoggingAuditEventDestinations.loading ||
        this.$apollo.queries.amazonS3AuditEventDestinations.loading
      );
    },
    isInstance() {
      return this.groupPath === 'instance';
    },
    showEmptyState() {
      return (
        !this.destinationsCount &&
        !this.gcpLoggingDestinationsCount &&
        !this.amazonS3DestinationsCount &&
        !this.isEditorVisible
      );
    },
    destinationsCount() {
      return this.externalAuditEventDestinations?.length ?? 0;
    },
    gcpLoggingDestinationsCount() {
      return this.gcpLoggingAuditEventDestinations?.length ?? 0;
    },
    amazonS3DestinationsCount() {
      return this.amazonS3AuditEventDestinations?.length ?? 0;
    },
    totalCount() {
      return (
        this.destinationsCount + this.gcpLoggingDestinationsCount + this.amazonS3DestinationsCount
      );
    },
    destinationQuery() {
      return this.isInstance ? instanceExternalDestinationsQuery : externalDestinationsQuery;
    },
    gcpLoggingDestinationQuery() {
      return this.isInstance ? instanceGcpLoggingDestinationsQuery : gcpLoggingDestinationsQuery;
    },
    amazonS3DestinationQuery() {
      return this.isInstance ? instanceAmazonS3DestinationsQuery : amazonS3DestinationsQuery;
    },
    destinationOptions() {
      return [
        {
          text: ADD_HTTP,
          action: () => {
            this.showEditor(DESTINATION_TYPE_HTTP);
          },
        },
        {
          text: ADD_GCP_LOGGING,
          action: () => {
            this.showEditor(DESTINATION_TYPE_GCP_LOGGING);
          },
        },
        {
          text: ADD_AMAZON_S3,
          action: () => {
            this.showEditor(DESTINATION_TYPE_AMAZON_S3);
          },
        },
      ];
    },
  },
  methods: {
    showEditor(type) {
      this.editorType = type;
      this.isEditorVisible = true;
    },
    hideEditor() {
      this.isEditorVisible = false;
    },
    clearSuccessMessage() {
      this.successMessage = null;
    },
    refreshDestinations() {
      return this.$apollo.queries.externalAuditEventDestinations.refetch();
    },
    async onAddedDestination() {
      this.hideEditor();
      this.successMessage = ADD_STREAM_MESSAGE;
    },
    async onUpdatedDestination() {
      this.hideEditor();
    },
    async onDeletedDestination(id) {
      removeAuditEventsStreamingDestination({
        store: this.$apollo.provider.defaultClient,
        fullPath: this.groupPath,
        destinationId: id,
      });

      if (this.totalCount > 1) {
        this.successMessage = DELETE_STREAM_MESSAGE;
      } else {
        this.clearSuccessMessage();
      }
    },
    async onDeletedGcpLoggingDestination(id) {
      removeGcpLoggingAuditEventsStreamingDestination({
        store: this.$apollo.provider.defaultClient,
        fullPath: this.groupPath,
        destinationId: id,
      });

      if (this.totalCount > 1) {
        this.successMessage = DELETE_STREAM_MESSAGE;
      } else {
        this.clearSuccessMessage();
      }
    },
    async onDeletedAmazonS3Destination(id) {
      removeAmazonS3AuditEventsStreamingDestination({
        store: this.$apollo.provider.defaultClient,
        fullPath: this.groupPath,
        destinationId: id,
      });

      if (this.totalCount > 1) {
        this.successMessage = DELETE_STREAM_MESSAGE;
      } else {
        this.clearSuccessMessage();
      }
    },
  },
  apollo: {
    externalAuditEventDestinations: {
      query() {
        return this.destinationQuery;
      },
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      skip() {
        return !this.groupPath;
      },
      update(data) {
        const destinations = this.isInstance
          ? data.instanceExternalAuditEventDestinations.nodes
          : data.group.externalAuditEventDestinations.nodes;
        return destinations;
      },
      error() {
        createAlert({
          message: FETCHING_ERROR,
        });

        this.clearSuccessMessage();
      },
    },
    gcpLoggingAuditEventDestinations: {
      query() {
        return this.gcpLoggingDestinationQuery;
      },
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      skip() {
        return !this.groupPath;
      },
      update(data) {
        const destinations = this.isInstance
          ? data.instanceGoogleCloudLoggingConfigurations.nodes
          : data.group.googleCloudLoggingConfigurations.nodes;
        return destinations;
      },
      error() {
        createAlert({
          message: FETCHING_ERROR,
        });

        this.clearSuccessMessage();
      },
    },
    amazonS3AuditEventDestinations: {
      query() {
        return this.amazonS3DestinationQuery;
      },
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      skip() {
        return !this.groupPath;
      },
      update(data) {
        const destinations = this.isInstance
          ? data.auditEventsInstanceAmazonS3Configurations.nodes
          : data.group.amazonS3Configurations.nodes;
        return destinations;
      },
      error() {
        createAlert({
          message: FETCHING_ERROR,
        });

        this.clearSuccessMessage();
      },
    },
  },
  i18n: {
    ADD_STREAM,
    ADD_HTTP,
    ADD_GCP_LOGGING,
    ADD_AMAZON_S3,
    FETCHING_ERROR,
    streamsLabel,
  },
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
};
</script>

<template>
  <gl-loading-icon v-if="isLoading" size="lg" />
  <stream-empty-state v-else-if="showEmptyState" @add="showEditor" />
  <div v-else>
    <gl-alert
      v-if="successMessage"
      :dismissible="true"
      class="gl-mb-4"
      variant="success"
      @dismiss="clearSuccessMessage"
    >
      {{ successMessage }}
    </gl-alert>
    <div class="gl-mb-6 gl-mt-3 gl-flex gl-items-center gl-justify-between">
      <h4 class="gl-m-0">
        {{ $options.i18n.streamsLabel(totalCount) }}
      </h4>
      <gl-disclosure-dropdown
        :toggle-text="$options.i18n.ADD_STREAM"
        category="primary"
        variant="confirm"
        data-testid="dropdown-toggle"
        :items="destinationOptions"
      />
    </div>
    <div v-if="isEditorVisible" class="gl-border gl-mb-4 gl-rounded-base gl-p-4">
      <stream-destination-editor
        v-if="editorType === $options.DESTINATION_TYPE_HTTP"
        @added="onAddedDestination"
        @error="clearSuccessMessage"
        @cancel="hideEditor"
      />
      <stream-gcp-logging-destination-editor
        v-else-if="editorType === $options.DESTINATION_TYPE_GCP_LOGGING"
        @added="onAddedDestination"
        @error="clearSuccessMessage"
        @cancel="hideEditor"
      />
      <stream-amazon-s3-destination-editor
        v-else-if="editorType === $options.DESTINATION_TYPE_AMAZON_S3"
        @added="onAddedDestination"
        @error="clearSuccessMessage"
        @cancel="hideEditor"
      />
    </div>
    <ul class="content-list gl-border-t gl-border-subtle" data-testid="stream-destinations">
      <stream-item
        v-for="item in externalAuditEventDestinations"
        :key="item.id"
        :item="item"
        :type="$options.DESTINATION_TYPE_HTTP"
        @deleted="onDeletedDestination(item.id)"
        @updated="onUpdatedDestination"
        @error="clearSuccessMessage"
      />
      <stream-item
        v-for="item in gcpLoggingAuditEventDestinations"
        :key="item.id"
        :item="item"
        :type="$options.DESTINATION_TYPE_GCP_LOGGING"
        @deleted="onDeletedGcpLoggingDestination(item.id)"
        @updated="onUpdatedDestination"
        @error="clearSuccessMessage"
      />
      <stream-item
        v-for="item in amazonS3AuditEventDestinations"
        :key="item.id"
        :item="item"
        :type="$options.DESTINATION_TYPE_AMAZON_S3"
        @deleted="onDeletedAmazonS3Destination(item.id)"
        @updated="onUpdatedDestination"
        @error="clearSuccessMessage"
      />
    </ul>
  </div>
</template>
