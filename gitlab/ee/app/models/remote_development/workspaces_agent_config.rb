# frozen_string_literal: true

module RemoteDevelopment
  class WorkspacesAgentConfig < ApplicationRecord
    # NOTE: See the following comment for the reasoning behind the `Workspaces` prefix of this table/model:
    #       https://gitlab.com/gitlab-org/gitlab/-/issues/410045#note_1385602915

    include Sortable

    ignore_column :max_hours_before_termination_limit, remove_with: '17.11', remove_after: '2025-03-20'
    ignore_column :default_max_hours_before_termination, remove_with: '17.11', remove_after: '2025-03-20'

    UNLIMITED_QUOTA = -1
    MIN_HOURS_BEFORE_TERMINATION = 1

    has_paper_trail versions: {
      class_name: 'RemoteDevelopment::WorkspacesAgentConfigVersion'
    }

    belongs_to :agent,
      class_name: 'Clusters::Agent', foreign_key: 'cluster_agent_id',
      inverse_of: :unversioned_latest_workspaces_agent_config

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

    validates :image_pull_secrets,
      json_schema: { filename: 'workspaces_agent_configs_image_pull_secrets', detail_errors: true }
    validates :image_pull_secrets, 'remote_development/image_pull_secrets': true

    validates :max_active_hours_before_stop,
      numericality: {
        only_integer: true, greater_than_or_equal_to: 1,
        less_than_or_equal_to: WorkspaceOperations::MaxHoursBeforeTermination::MAX_HOURS_BEFORE_TERMINATION
      }
    validates :max_stopped_hours_before_termination,
      numericality: {
        only_integer: true, greater_than_or_equal_to: 1,
        less_than_or_equal_to: WorkspaceOperations::MaxHoursBeforeTermination::MAX_HOURS_BEFORE_TERMINATION
      }

    validate :validate_sum_of_delayed_termination_fields_does_not_exceed_max_hours_before_termination_limit

    validate :validate_allow_privilege_escalation

    scope :by_cluster_agent_ids, ->(ids) { where(cluster_agent_id: ids) }

    private

    def validate_sum_of_delayed_termination_fields_does_not_exceed_max_hours_before_termination_limit
      max_hours_before_termination = WorkspaceOperations::MaxHoursBeforeTermination::MAX_HOURS_BEFORE_TERMINATION

      return if max_active_hours_before_stop + max_stopped_hours_before_termination <= max_hours_before_termination

      msg = "Sum of max_active_hours_before_stop and max_stopped_hours_before_termination must not exceed " \
        "%{maximum_hours_before_termination} hours"

      errors.add(:base, format(_(msg), maximum_hours_before_termination: max_hours_before_termination))
      false
    end

    # allow_privilege_escalation is allowed to be set to true only if
    # - either use_kubernetes_user_namespaces is true
    # - or default_runtime_class is set to a non-empty value
    # This ensures that unsafe usage of allow_privilege_escalation is not allowed.
    def validate_allow_privilege_escalation
      return if allow_privilege_escalation == false
      return if use_kubernetes_user_namespaces == true || default_runtime_class.present?

      msg = 'can be true only if either use_kubernetes_user_namespaces is true or default_runtime_class is non-empty'
      errors.add(:allow_privilege_escalation, format(_(msg)))
      false
    end
  end
end
