# frozen_string_literal: true

# TODO: clusterAgent.remoteDevelopmentAgentConfig GraphQL is deprecated - remove in 17.10 - https://gitlab.com/gitlab-org/gitlab/-/issues/480769
module RemoteDevelopment
  class RemoteDevelopmentAgentConfigsFinder
    # Executes a query to find agent configurations based on the provided filter arguments.
    #
    # @param [User, QA::Resource::User] current_user The user making the request. Must have permission
    #   to access workspaces.
    # @param [Array<Integer>] ids A list of specific RemoteDevelopmentAgentConfig IDs to filter by (optional).
    # @param [Array<Integer>] cluster_agent_ids A list of ClusterAgent IDs to filter by (optional).
    # @return [ActiveRecord::Relation<RemoteDevelopmentAgentConfig>]
    #   A collection of filtered RemoteDevelopmentAgentConfig records ordered by ID descending.
    def self.execute(current_user:, ids: [], cluster_agent_ids: [])
      return RemoteDevelopmentAgentConfig.none unless current_user.can?(:access_workspaces_feature)

      filter_arguments = {
        ids: ids,
        cluster_agent_ids: cluster_agent_ids
      }

      filter_argument_types = {
        ids: Integer,
        cluster_agent_ids: Integer
      }

      FilterArgumentValidator.validate_filter_argument_types!(filter_argument_types, filter_arguments)
      FilterArgumentValidator.validate_at_least_one_filter_argument_provided!(**filter_arguments)

      collection_proxy = RemoteDevelopmentAgentConfig.all
      collection_proxy = collection_proxy.id_in(ids) if ids.present?
      collection_proxy = collection_proxy.by_cluster_agent_ids(cluster_agent_ids) if cluster_agent_ids.present?

      collection_proxy.order_id_desc
    end
  end
end
