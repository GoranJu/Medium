# frozen_string_literal: true

# TODO: clusterAgent.remoteDevelopmentAgentConfig GraphQL is deprecated - remove in 17.10 - https://gitlab.com/gitlab-org/gitlab/-/issues/480769
module RemoteDevelopment
  class RemoteDevelopmentAgentConfig < ApplicationRecord
    self.table_name = "workspaces_agent_configs"

    # NOTE: See the following comment for the reasoning behind the `RemoteDevelopment` prefix of this table/model:
    #       https://gitlab.com/gitlab-org/gitlab/-/issues/410045#note_1385602915

    include Sortable

    ignore_column :max_hours_before_termination_limit, remove_with: '17.11', remove_after: '2025-03-20'
    ignore_column :default_max_hours_before_termination, remove_with: '17.11', remove_after: '2025-03-20'

    UNLIMITED_QUOTA = -1

    belongs_to :agent,
      class_name: 'Clusters::Agent', foreign_key: 'cluster_agent_id', inverse_of: :remote_development_agent_config

    # noinspection RailsParamDefResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    has_many :workspaces, through: :agent, source: :workspaces

    validates :agent, presence: true
    validates :dns_zone, hostname: true
    validates :enabled, inclusion: { in: [true, false] }

    validates :network_policy_egress,
      json_schema: { filename: 'workspaces_agent_configs_network_policy_egress' }
    validates :network_policy_egress, 'remote_development/network_policy_egress': true
    validates :default_resources_per_workspace_container,
      json_schema: { filename: 'workspaces_agent_configs_workspace_container_resources' }
    validates :default_resources_per_workspace_container, 'remote_development/workspace_container_resources': true
    validates :max_resources_per_workspace,
      json_schema: { filename: 'workspaces_agent_configs_workspace_container_resources' }
    validates :max_resources_per_workspace, 'remote_development/workspace_container_resources': true
    validates :workspaces_quota, numericality: { only_integer: true, greater_than_or_equal_to: UNLIMITED_QUOTA }
    validates :workspaces_per_user_quota,
      numericality: { only_integer: true, greater_than_or_equal_to: UNLIMITED_QUOTA }
    validates :allow_privilege_escalation, inclusion: { in: [true, false] }
    validates :use_kubernetes_user_namespaces, inclusion: { in: [true, false] }
    validates :default_runtime_class, 'remote_development/default_runtime_class': true
    validates :annotations, 'remote_development/annotations': true
    validates :labels, 'remote_development/labels': true

    scope :by_cluster_agent_ids, ->(ids) { where(cluster_agent_id: ids) }
  end
end
