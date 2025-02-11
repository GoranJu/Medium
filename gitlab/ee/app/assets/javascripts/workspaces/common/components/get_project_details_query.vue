<script>
import { logError } from '~/lib/logger';
import getProjectDetailsQuery from '../graphql/queries/get_project_details.query.graphql';
import getRemoteDevelopmentClusterAgents from '../graphql/queries/get_remote_development_cluster_agents.query.graphql';

export default {
  props: {
    projectFullPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    projectDetails: {
      query: getProjectDetailsQuery,
      variables() {
        return {
          projectFullPath: this.projectFullPath,
        };
      },
      skip() {
        return !this.projectFullPath;
      },
      update() {
        return [];
      },
      error(error) {
        logError(error);
      },
      async result(result) {
        if (result.error || !result.data.project) {
          this.$emit('error');
          return;
        }

        const { nameWithNamespace, repository, group, id } = result.data.project;

        const rootRef = repository ? repository.rootRef : null;

        if (!group) {
          // Guard clause: do not attempt to find agents if project does not have a group
          this.$emit('result', {
            id,
            fullPath: this.projectFullPath,
            nameWithNamespace,
            clusterAgents: [],
            rootRef,
          });
          return;
        }

        const { clusterAgents, errors } = await this.fetchRemoteDevelopmentClusterAgents(
          group.fullPath,
        );

        if (Array.isArray(errors) && errors.length) {
          errors.forEach((error) => logError(error));
          this.$emit('error');
          return;
        }

        this.$emit('result', {
          id,
          fullPath: this.projectFullPath,
          nameWithNamespace,
          clusterAgents,
          rootRef,
        });
      },
    },
  },
  methods: {
    async fetchRemoteDevelopmentClusterAgents(namespace) {
      try {
        // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
        const { data, error } = await this.$apollo.query({
          query: getRemoteDevelopmentClusterAgents,
          variables: { namespace },
        });

        if (error) {
          // NOTE: It seems to be impossible to have test coverage for this line
          //       with the current version of mock-apollo-client. Any type of
          //       mock error is always thrown and caught below instead of
          //       being returned.
          return { errors: [error] };
        }

        return {
          clusterAgents:
            data.namespace?.remoteDevelopmentClusterAgents?.nodes.map(
              ({ id, name, project, workspacesAgentConfig }) => ({
                value: id,
                text: `${project.nameWithNamespace} / ${name}`,
                defaultMaxHoursBeforeTermination:
                  workspacesAgentConfig.defaultMaxHoursBeforeTermination,
              }),
            ) || [],
        };
      } catch (error) {
        return { errors: [error] };
      }
    },
  },
  render() {
    return this.$scopedSlots.default?.();
  },
};
</script>
