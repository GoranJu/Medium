<script>
import { buildClient } from '~/observability/client';
import MetricsDetails from './details/metrics_details.vue';

export default {
  components: {
    MetricsDetails,
  },
  props: {
    metricId: {
      type: String,
      required: true,
    },
    metricType: {
      type: String,
      required: true,
    },
    metricsIndexUrl: {
      required: true,
      type: String,
    },
    createIssueUrl: {
      required: true,
      type: String,
    },
    apiConfig: {
      type: Object,
      required: true,
    },
    projectFullPath: {
      type: String,
      required: true,
    },
    projectId: {
      type: Number,
      required: true,
    },
    tracingIndexUrl: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      observabilityClient: buildClient(this.apiConfig),
    };
  },
};
</script>

<template>
  <metrics-details
    :metric-id="metricId"
    :metric-type="metricType"
    :metrics-index-url="metricsIndexUrl"
    :observability-client="observabilityClient"
    :create-issue-url="createIssueUrl"
    :project-full-path="projectFullPath"
    :project-id="projectId"
    :tracing-index-url="tracingIndexUrl"
  />
</template>
