# frozen_string_literal: true

module EE
  module GlobalPolicy
    extend ActiveSupport::Concern

    prepended do
      include ::Gitlab::Utils::StrongMemoize

      condition(:operations_dashboard_available) do
        License.feature_available?(:operations_dashboard)
      end

      condition(:pages_size_limit_available) do
        License.feature_available?(:pages_size_limit)
      end

      condition(:adjourned_project_deletion_available) do
        License.feature_available?(:adjourned_deletion_for_projects_and_groups)
      end

      condition(:export_user_permissions_available) do
        ::License.feature_available?(:export_user_permissions)
      end

      condition(:top_level_group_creation_enabled) do
        if ::Gitlab.com?
          ::Feature.enabled?(:top_level_group_creation_enabled, type: :ops)
        else
          true
        end
      end

      condition(:clickhouse_main_database_available) do
        ::Gitlab::ClickHouse.configured?
      end

      condition(:instance_devops_adoption_available) do
        ::License.feature_available?(:instance_level_devops_adoption)
      end

      condition(:runner_performance_insights_available) do
        ::License.feature_available?(:runner_performance_insights)
      end

      condition(:runner_upgrade_management_available) do
        License.feature_available?(:runner_upgrade_management)
      end

      condition(:service_accounts_available) do
        ::License.feature_available?(:service_accounts)
      end

      condition(:instance_external_audit_events_enabled) do
        ::License.feature_available?(:external_audit_events)
      end

      condition(:code_suggestions_licensed) do
        next true if ::Gitlab.org_or_com?

        ::License.feature_available?(:code_suggestions)
      end

      condition(:code_suggestions_enabled_for_user) do
        next false unless @user
        next true if @user.allowed_to_use?(:code_suggestions)
        next true if amazon_q_feature_available?(@user, :code_suggestions)

        if ::Ai::FeatureSetting.code_suggestions_self_hosted?
          next @user.allowed_to_use?(:code_suggestions, service_name: :self_hosted_models)
        end

        false
      end

      condition(:ai_features_enabled) do
        ::Gitlab::CurrentSettings.duo_features_enabled?
      end

      condition(:ai_features_banned) do
        ::Gitlab::CurrentSettings.lock_duo_features_enabled?
      end

      condition(:user_allowed_to_use_glab_ask_git_command) do
        @user.allowed_to_use?(:glab_ask_git_command, licensed_feature: :glab_ask_git_command)
      end

      rule { ai_features_enabled & user_allowed_to_use_glab_ask_git_command }.policy do
        enable :access_glab_ask_git_command
      end

      condition(:duo_chat_enabled_for_user) do
        next true if amazon_q_feature_available?(@user, :duo_chat)

        if duo_chat_self_hosted?
          self_hosted_models_available_for?(@user)
        else
          duo_chat.allowed_for?(@user)
        end
      end

      condition(:user_belongs_to_paid_namespace) do
        next false unless @user

        @user.belongs_to_paid_namespace?
      end

      condition(:custom_roles_allowed) do
        ::License.feature_available?(:custom_roles)
      end

      condition(:default_roles_assignees_allowed) do
        ::License.feature_available?(:default_roles_assignees)
      end

      condition(:user_allowed_to_manage_self_hosted_models_settings) do
        next false if ::Feature.disabled?(:allow_self_hosted_features_for_com) &&
          ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

        ::License.current&.ultimate? && # Replace with license :ai_self_hosted_model for GA
          ::GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.active.exists?
      end

      condition(:x_ray_available) do
        next true if ::Gitlab::Saas.feature_available?(:code_suggestions_x_ray)

        ::License.feature_available?(:code_suggestions)
      end

      rule { x_ray_available }.enable :access_x_ray_on_instance

      rule { ~anonymous & operations_dashboard_available }.enable :read_operations_dashboard

      condition(:remote_development_feature_licensed) do
        License.feature_available?(:remote_development)
      end

      MemberRole.all_customizable_admin_permission_keys.each do |ability|
        desc "Admin custom role that enables #{ability.to_s.tr('_', ' ')}"
        condition(:"custom_role_enables_#{ability}") do
          custom_role_ability(@user).allowed?(ability)
        end
      end

      rule { ~anonymous & remote_development_feature_licensed }.policy do
        enable :access_workspaces_feature
      end

      rule { admin & instance_devops_adoption_available }.policy do
        enable :manage_devops_adoption_namespaces
        enable :view_instance_devops_adoption
      end

      rule { admin }.policy do
        enable :destroy_licenses
        enable :manage_subscription
        enable :read_admin_subscription
        enable :read_all_geo
        enable :read_all_workspaces
        enable :read_cloud_connector_status
        enable :read_jobs_statistics
        enable :read_licenses
        enable :read_runner_usage
      end

      rule { admin & user_allowed_to_manage_self_hosted_models_settings }.policy do
        enable :manage_self_hosted_models_settings
      end

      rule { admin & custom_roles_allowed }.policy do
        enable :admin_member_role
        enable :view_member_roles
        enable :read_admin_member_role
      end

      rule { admin & default_roles_assignees_allowed }.policy do
        enable :view_member_roles
      end

      rule { ~anonymous & custom_roles_allowed }.policy do
        enable :read_member_role
      end

      rule { admin & pages_size_limit_available }.enable :update_max_pages_size

      rule { ~runner_performance_insights_available }.policy do
        prevent :read_jobs_statistics
        prevent :read_runner_usage
      end

      rule { ~clickhouse_main_database_available }.prevent :read_runner_usage

      rule { admin & service_accounts_available }.enable :admin_service_accounts

      rule { ~anonymous }.policy do
        enable :view_productivity_analytics
      end

      rule { ~(admin | allow_to_manage_default_branch_protection) }.policy do
        prevent :create_group_with_default_branch_protection
      end

      rule { adjourned_project_deletion_available }.policy do
        enable :list_removable_projects
      end

      rule { export_user_permissions_available & admin }.enable :export_user_permissions

      rule { can?(:create_group) }.enable :create_group_via_api
      rule { ~top_level_group_creation_enabled }.prevent :create_group_via_api

      rule { admin & instance_external_audit_events_enabled }.policy do
        enable :admin_instance_external_audit_events
      end

      rule do
        code_suggestions_licensed & ai_features_enabled & code_suggestions_enabled_for_user
      end.enable :access_code_suggestions

      rule { duo_chat_enabled_for_user & ~ai_features_banned }.enable :access_duo_chat

      rule { runner_upgrade_management_available | user_belongs_to_paid_namespace }.enable :read_runner_upgrade_status

      rule { security_policy_bot }.policy do
        enable :access_git
      end

      rule { custom_role_enables_read_admin_dashboard }.policy do
        enable :access_admin_area
        enable :read_admin_dashboard
      end

      rule { custom_role_enables_read_admin_cicd }.policy do
        enable :read_admin_cicd
      end

      rule { custom_role_enables_read_admin_monitoring }.policy do
        enable :read_admin_audit_log
      end

      rule { custom_role_enables_read_admin_subscription }.policy do
        enable :read_admin_subscription
        enable :read_billable_member
        enable :read_licenses
      end

      rule { custom_role_enables_read_admin_users }.enable :read_admin_users
    end

    def duo_chat
      CloudConnector::AvailableServices.find_by_name(:duo_chat)
    end

    # Check whether a user is allowed to use Duo Chat powered by self-hosted models
    def duo_chat_self_hosted?
      ::Ai::FeatureSetting.find_by_feature(:duo_chat)&.self_hosted?
    end

    def self_hosted_models_available_for?(user)
      CloudConnector::AvailableServices.find_by_name(:self_hosted_models).allowed_for?(user)
    end

    def custom_role_ability(user)
      strong_memoize_with(:custom_role_ability, user) do
        ::Authz::CustomAbility.new(user)
      end
    end

    def amazon_q_feature_available?(user, feature_name)
      return false unless ::Feature.enabled?(:amazon_q_chat_and_code_suggestions, user) && ::Ai::AmazonQ.connected?

      user.allowed_to_use?(feature_name, service_name: :amazon_q_integration, licensed_feature: :amazon_q)
    end
  end
end
