# frozen_string_literal: true

module RemoteDevelopment
  class Workspace < ApplicationRecord
    include Sortable
    include RemoteDevelopment::WorkspaceOperations::States
    include ::Gitlab::Utils::StrongMemoize
    include SafelyChangeColumnDefault

    columns_changing_default :desired_config_generator_version

    ignore_column :devfile_ref, remove_with: '17.8', remove_after: '2025-01-08'
    ignore_column :max_hours_before_termination, remove_with: '17.11', remove_after: '2025-03-20'

    belongs_to :user, inverse_of: :workspaces
    belongs_to :project, inverse_of: :workspaces
    belongs_to :agent, class_name: 'Clusters::Agent', foreign_key: 'cluster_agent_id', inverse_of: :workspaces
    belongs_to :personal_access_token, inverse_of: :workspace

    attribute :desired_config_generator_version,
      default: ::RemoteDevelopment::WorkspaceOperations::DesiredConfigGeneratorVersion::LATEST_VERSION

    # TODO: clusterAgent.remoteDevelopmentAgentConfig GraphQL is deprecated - remove in 17.10 - https://gitlab.com/gitlab-org/gitlab/-/issues/480769
    # noinspection RailsParamDefResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    has_one :remote_development_agent_config, through: :agent, source: :remote_development_agent_config
    has_many :workspace_variables, class_name: 'RemoteDevelopment::WorkspaceVariable', inverse_of: :workspace
    # Currently we only support :environment type for user provided variables
    has_many :user_provided_workspace_variables, -> {
      user_provided.with_variable_type_environment.order_id_desc
    }, class_name: 'RemoteDevelopment::WorkspaceVariable', inverse_of: :workspace

    validates :user, presence: true
    validates :agent, presence: true
    validates :personal_access_token, presence: true
    validates :desired_config_generator_version, presence: true
    validates :workspaces_agent_config_version, presence: true, if: -> {
      agent&.unversioned_latest_workspaces_agent_config
    }

    # See https://gitlab.com/gitlab-org/remote-development/gitlab-remote-development-docs/blob/main/doc/architecture.md?plain=0#workspace-states
    # for state validation rules
    validates :desired_state, inclusion: { in: VALID_DESIRED_STATES }
    validates :actual_state, inclusion: { in: VALID_ACTUAL_STATES }

    validate :validate_workspaces_agent_config_present, if: -> { agent }
    validate :validate_workspaces_agent_config_version_is_within_range, if: -> do
      workspaces_agent_config && workspaces_agent_config_version
    end
    validate :validate_agent_config_enabled, if: ->(workspace) do
      workspace.new_record? && workspaces_agent_config
    end

    validate :enforce_permanent_termination
    validate :enforce_quotas, if: ->(workspace) do
      workspace.new_record? && workspaces_agent_config
    end

    scope :with_desired_state_updated_more_recently_than_last_response_to_agent, -> do
      where('desired_state_updated_at >= responded_to_agent_at').or(where(responded_to_agent_at: nil))
    end

    scope :forced_to_include_all_resources, -> { where(force_include_all_resources: true) }
    scope :by_names, ->(names) { where(name: names) }
    scope :by_user_ids, ->(ids) { where(user_id: ids) }
    scope :by_project_ids, ->(ids) { where(project_id: ids) }
    scope :by_agent_ids, ->(ids) { where(cluster_agent_id: ids) }
    scope :by_actual_states, ->(actual_states) { where(actual_state: actual_states) }
    scope :desired_state_not_terminated, -> do
      where.not(
        desired_state: RemoteDevelopment::WorkspaceOperations::States::TERMINATED
      )
    end
    scope :actual_state_not_terminated, -> do
      where.not(
        actual_state: RemoteDevelopment::WorkspaceOperations::States::TERMINATED
      )
    end

    before_validation :set_workspaces_agent_config_version,
      on: :create, if: -> { agent&.unversioned_latest_workspaces_agent_config }

    # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-32287
    before_save :touch_desired_state_updated_at, if: ->(workspace) do
      workspace.new_record? || workspace.desired_state_changed?
    end

    def workspaces_agent_config
      # If no agent or workspaces_agent_configs record exists, return nil
      return unless agent&.unversioned_latest_workspaces_agent_config

      if workspaces_agent_config_version.nil?
        raise "#workspaces_agent_config cannot be called until #workspaces_agent_config_version is set. " \
          "Call set_workspaces_agent_config_version first to automatically set it."
      end

      actual_workspaces_agent_configs_table_record = agent.unversioned_latest_workspaces_agent_config

      # If the workspaces_agent_config_version is not nil, then we will try to retrieve and reify the version
      # from the PaperTrail versions table. If we don't find one, that means that the version is out of range
      # (for a valid record, this should only ever be the case where the length of the versions array + 1).
      # In this case we should return the latest version of the workspaces_agent_config.
      # The `try()` approach avoids having to do a length check on the versions array, which would result in
      # multiple `COUNT` queries to the database. The `try()` approach also ensures we can handle any invalid
      # version numbers gracefully by just defaulting to the actual workspaces_agent_config record.
      reified_version =
        actual_workspaces_agent_configs_table_record.versions[workspaces_agent_config_version].try(:reify)
      reified_version || actual_workspaces_agent_configs_table_record
    end

    def desired_state_updated_more_recently_than_last_response_to_agent?
      return true if responded_to_agent_at.nil?

      desired_state_updated_at > responded_to_agent_at
    end

    def workspaces_count_for_current_user_and_agent
      Workspace
        .desired_state_not_terminated
        .by_user_ids(user_id)
        .by_agent_ids(cluster_agent_id)
        .count
    end

    strong_memoize_attr :workspaces_count_for_current_user_and_agent

    def workspaces_count_for_current_agent
      Workspace
        .desired_state_not_terminated
        .by_agent_ids(cluster_agent_id)
        .count
    end

    strong_memoize_attr :workspaces_count_for_current_agent

    def exceeds_workspaces_per_user_quota?
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      quota = workspaces_agent_config.workspaces_per_user_quota
      return true if quota == 0
      return false if quota == -1

      workspaces_count_for_current_user_and_agent >= quota
    end

    def exceeds_workspaces_quota?
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      quota = workspaces_agent_config.workspaces_quota
      return true if quota == 0
      return false if quota == -1

      workspaces_count_for_current_agent >= quota
    end

    def url
      URI::HTTPS.build(host: "#{url_prefix}.#{workspaces_agent_config.dns_zone}",
        path: '/',
        query: url_query_string).to_s
    end

    # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/503465 - Remove in 19.0
    def devfile_web_url
      devfile_path.nil? ? nil : project.http_url_to_repo.gsub(/\.git\Z/, "/-/blob/#{project_ref}/#{devfile_path}")
    end

    private

    def set_workspaces_agent_config_version
      # If no versions for this workspace exist yet in the `workspaces_agent_config_versions` table, then
      # the `workspace.workspaces_agent_config_version` field will be set to `0`.
      # This indicates the actual associated `agent.unversioned_latest_workspaces_agent_config` should be used directly.
      # Otherwise, if a version exists in the `workspaces_agent_config_versions` table, then
      # the `workspace.workspaces_agent_config_version` field will be set to `1` or greater, which
      # indicates that the corresponding PaperTrail reified version of the model should be used.
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      self.workspaces_agent_config_version = agent.unversioned_latest_workspaces_agent_config.versions.size
    end

    def validate_workspaces_agent_config_version_is_within_range
      if workspaces_agent_config_version < 0
        errors.add(:workspaces_agent_config_version, _('must be greater than or equal to 0'))
        return false
      end

      if workspaces_agent_config_version > agent.unversioned_latest_workspaces_agent_config.versions.size
        errors.add(:workspaces_agent_config_version, _('must be no greater than the number of agent config versions'))
        return false
      end

      true
    end

    def validate_agent_config_enabled
      return true if workspaces_agent_config.enabled

      errors.add(:agent, _("must have the 'enabled' flag set to true"))
      false
    end

    def validate_workspaces_agent_config_present
      return true if agent.unversioned_latest_workspaces_agent_config.present?

      errors.add(:agent, _("must have an associated workspaces agent config"))
      false
    end

    def enforce_permanent_termination
      return unless persisted? && desired_state_changed? && desired_state_was == WorkspaceOperations::States::TERMINATED

      errors.add(:desired_state, "is 'Terminated', and cannot be updated. Create a new workspace instead.")
    end

    # rubocop:disable Layout/LineLength  -- Long messages for UI
    def enforce_quotas
      agent_config = workspaces_agent_config
      if exceeds_workspaces_per_user_quota?
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        errors.add :base,
          format(
            s_('RemoteDevelopment|You cannot create a workspace because you already have "%{count}" existing workspaces for the given agent with a per user quota of "%{quota}" workspaces'),
            count: workspaces_count_for_current_user_and_agent,
            quota: agent_config.workspaces_per_user_quota
          )
      elsif exceeds_workspaces_quota?
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        errors.add :base,
          format(
            s_('RemoteDevelopment|You cannot create a workspace because there are already "%{count}" existing workspaces for the given agent with a total quota of "%{quota}" workspaces'),
            count: workspaces_count_for_current_agent,
            quota: agent_config.workspaces_quota
          )
      end
    end

    # rubocop:enable Layout/LineLength  -- Long messages for UI

    def touch_desired_state_updated_at
      self.desired_state_updated_at = Time.current.utc
    end
  end
end
