<script>
import { parseGraphQLIssueLinksToRelatedIssues } from '~/observability/utils';
import getLogsRelatedIssues from './graphql/get_logs_related_issues.query.graphql';

export default {
  props: {
    projectFullPath: {
      type: String,
      required: true,
    },
    log: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      relatedIssues: [],
      error: null,
      isLoading: false,
    };
  },
  apollo: {
    relatedIssues: {
      query: getLogsRelatedIssues,
      variables() {
        const {
          trace_id: traceId,
          fingerprint,
          severity_number: severityNumber,
          service_name: service,
          timestamp,
        } = this.log;
        return {
          projectFullPath: this.projectFullPath,
          traceId,
          fingerprint,
          severityNumber,
          service,
          timestamp,
        };
      },
      skip() {
        return !this.log;
      },
      update(data) {
        const links = data.project?.observabilityLogsLinks?.nodes || [];
        return parseGraphQLIssueLinksToRelatedIssues(links);
      },
      error(error) {
        this.error = error;
      },
    },
  },
  render() {
    if (!this.$scopedSlots.default) return null;

    return this.$scopedSlots.default({
      issues: this.relatedIssues,
      loading: this.$apollo.loading,
      error: this.error,
    });
  },
};
</script>
