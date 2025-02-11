# frozen_string_literal: true

module RemoteDevelopment
  module NamespaceClusterAgentMappingOperations
    module Delete
      class MappingDeleter
        include Messages

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.delete(context)
          context => {
            namespace: Namespace => namespace,
            cluster_agent: Clusters::Agent => cluster_agent
          }

          delete_count = RemoteDevelopmentNamespaceClusterAgentMapping.delete_by(
            namespace_id: namespace.id,
            cluster_agent_id: cluster_agent.id
          )

          return Gitlab::Fp::Result.err(NamespaceClusterAgentMappingNotFound.new) if delete_count == 0

          Gitlab::Fp::Result.ok(NamespaceClusterAgentMappingDeleteSuccessful.new({}))
        end
      end
    end
  end
end
