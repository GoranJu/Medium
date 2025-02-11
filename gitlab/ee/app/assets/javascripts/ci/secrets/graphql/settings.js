import getSecretsQuery from './queries/client/get_secrets.query.graphql';

export const cacheConfig = {
  typePolicies: {
    Query: {
      fields: {
        group: {
          merge(existing = {}, incoming, { isReference }) {
            if (isReference(incoming)) {
              return existing;
            }
            return { ...existing, ...incoming };
          },
        },
        project: {
          merge(existing = {}, incoming, { isReference }) {
            if (isReference(incoming)) {
              return existing;
            }
            return { ...existing, ...incoming };
          },
        },
      },
    },
  },
};

// client-only field pagination
// return a slice of the cached data according to offset and limit
const clientSidePaginate = (sourceData, offset, limit) => ({
  ...sourceData,
  nodes: sourceData.nodes.slice(offset, offset + limit),
});

export const resolvers = {
  Group: {
    secrets({ fullPath }, { offset, limit }, { cache }) {
      const sourceData = cache.readQuery({
        query: getSecretsQuery,
        variables: { fullPath, isGroup: true },
      }).group.secrets;

      return clientSidePaginate(sourceData, offset, limit);
    },
  },
  Project: {
    secrets({ fullPath }, { offset, limit }, { cache }) {
      const sourceData = cache.readQuery({
        query: getSecretsQuery,
        variables: { fullPath, isProject: true },
      }).project.secrets;

      return clientSidePaginate(sourceData, offset, limit);
    },
  },
};
