# frozen_string_literal: true

module EE
  module Clusters
    module Agent
      extend ActiveSupport::Concern

      prepended do
        has_one :agent_url_configuration, class_name: 'Clusters::Agents::UrlConfiguration', inverse_of: :agent

        has_many :vulnerability_reads, class_name: 'Vulnerabilities::Read', foreign_key: :casted_cluster_agent_id

        has_many :workspaces,
          class_name: 'RemoteDevelopment::Workspace',
          foreign_key: 'cluster_agent_id',
          inverse_of: :agent

        # TODO: clusterAgent.remoteDevelopmentAgentConfig GraphQL is deprecated - remove in 17.10 - https://gitlab.com/gitlab-org/gitlab/-/issues/480769
        has_one :remote_development_agent_config,
          class_name: 'RemoteDevelopment::RemoteDevelopmentAgentConfig',
          inverse_of: :agent,
          foreign_key: :cluster_agent_id

        # WARNING: Do not use this `unversioned_latest_workspaces_agent_config`
        # association unless you are positive that is what you want to do!
        #
        # If you are attempting to get the associated WorkspacesAgentConfig
        # for a workspace, you should instead be directly using the
        # `workspace.workspaces_agent_config` method, which will return the proper
        # version of the config which is associated with that specific workspace.
        #
        # For more explanation, see:
        # https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/remote_development/README.md#workspaces_agent_configs-versioning
        has_one :unversioned_latest_workspaces_agent_config,
          class_name: 'RemoteDevelopment::WorkspacesAgentConfig',
          inverse_of: :agent,
          foreign_key: :cluster_agent_id

        has_many :remote_development_namespace_cluster_agent_mappings,
          class_name: 'RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping',
          inverse_of: :agent,
          foreign_key: 'cluster_agent_id'

        scope :for_projects, ->(projects) { where(project: projects) }
        scope :with_workspaces_agent_config, -> {
                                               joins(:unversioned_latest_workspaces_agent_config)
                                             }
        scope :without_workspaces_agent_config, -> do
          includes(:unversioned_latest_workspaces_agent_config).where(
            unversioned_latest_workspaces_agent_config: { cluster_agent_id: nil }
          )
        end
        scope :with_remote_development_enabled, -> do
          with_workspaces_agent_config.where(
            unversioned_latest_workspaces_agent_config: { enabled: true }
          )
        end
      end
    end
  end
end
