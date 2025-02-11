# frozen_string_literal: true

module EE
  module ProjectsHelper
    extend ::Gitlab::Utils::Override

    override :sidebar_operations_paths
    def sidebar_operations_paths
      super + %w[
        oncall_schedules
      ]
    end

    override :project_permissions_settings
    def project_permissions_settings(project)
      super.merge({
        requirementsAccessLevel: project.requirements_access_level,
        cveIdRequestEnabled: (project.public? && project.project_setting.cve_id_request_enabled?),
        duoFeaturesEnabled: (project.project_setting.duo_features_enabled?),
        sppRepositoryPipelineAccess: (project.project_setting.spp_repository_pipeline_access)
      })
    end

    override :show_no_ssh_key_message?
    def show_no_ssh_key_message?(project)
      !project.root_ancestor.enforce_ssh_certificates? && super
    end

    override :project_permissions_panel_data
    def project_permissions_panel_data(project)
      super.merge({
        canManageSecretManager: ::Feature.enabled?(:secrets_manager, project, type: :wip),
        requirementsAvailable: project.feature_available?(:requirements),
        licensedAiFeaturesAvailable: project.licensed_ai_features_available?,
        amazonQAvailable: Ai::AmazonQ.connected?,
        duoFeaturesLocked: project.project_setting.duo_features_enabled_locked?,
        requestCveAvailable: ::Gitlab.com?,
        cveIdRequestHelpPath: help_page_path('user/application_security/cve_id_request.md'),
        sppRepositoryPipelineAccessLocked: project.project_setting.spp_repository_pipeline_access_locked?,
        policySettingsAvailable: project.licensed_feature_available?(:security_orchestration_policies) &&
          ::Security::OrchestrationPolicyConfiguration.policy_management_project?(project)
      })
    end

    override :default_url_to_repo
    def default_url_to_repo(project = @project)
      case default_clone_protocol
      when 'krb5'
        project.kerberos_url_to_repo
      else
        super
      end
    end

    override :extra_default_clone_protocol
    def extra_default_clone_protocol
      if alternative_kerberos_url? && current_user
        "krb5"
      else
        super
      end
    end

    override :remove_project_message
    def remove_project_message(project)
      return super unless project.adjourned_deletion?

      date = permanent_deletion_date_formatted(project, Time.now.utc)
      _("Deleting a project places it into a read-only state until %{date}, at which point the project will be permanently deleted. Are you ABSOLUTELY sure?") %
        { date: date }
    end

    def approvals_app_data(project = @project)
      {
        project_id: project.id,
        can_edit: can_modify_approvers.to_s,
        can_modify_author_settings: can_modify_author_settings.to_s,
        can_modify_commiter_settings: can_modify_commiter_settings.to_s,
        can_read_security_policies: can_read_security_policies.to_s,
        saml_provider_enabled: saml_provider_enabled_for_project?(project).to_s,
        project_path: expose_path(api_v4_projects_path(id: project.id)),
        approvals_path: expose_path(api_v4_projects_merge_request_approval_setting_path(id: project.id)),
        rules_path: expose_path(api_v4_projects_approval_rules_path(id: project.id)),
        allow_multi_rule: project.multiple_approval_rules_available?.to_s,
        eligible_approvers_docs_path: help_page_path('user/project/merge_requests/approvals/rules.md', anchor: 'eligible-approvers'),
        security_configuration_path: project_security_configuration_path(project),
        coverage_check_help_page_path: help_page_path('ci/testing/code_coverage/_index.md', anchor: 'add-a-coverage-check-approval-rule'),
        group_name: project.root_ancestor.name,
        full_path: project.full_path,
        new_policy_path: expose_path(new_project_security_policy_path(project))
      }
    end

    def saml_provider_enabled_for_project?(project)
      group = project.root_ancestor
      return false unless group.is_a? Group

      !!group.saml_provider&.enabled?
    end

    def status_checks_app_data(project)
      {
        data: {
          project_id: project.id,
          status_checks_path: expose_path(api_v4_projects_external_status_checks_path(id: project.id))
        }
      }
    end

    def can_modify_approvers(project = @project)
      can?(current_user, :modify_approvers_rules, project)
    end

    def can_modify_author_settings(project = @project)
      can?(current_user, :modify_merge_request_author_setting, project)
    end

    def can_modify_commiter_settings(project = @project)
      can?(current_user, :modify_merge_request_committer_setting, project)
    end

    def can_read_security_policies(project = @project)
      can?(current_user, :read_security_orchestration_policies, project)
    end

    override :delete_immediately_message
    def delete_immediately_message(project)
      return super unless project.adjourned_deletion?

      date = permanent_deletion_date_formatted(project, Time.now.utc)

      message = _('This project is scheduled for deletion on %{strongOpen}%{date}%{strongClose}. ' \
        'This action will permanently delete this project, ' \
        'including all its resources, %{strongOpen}immediately%{strongClose}. This action cannot be undone.')

      ERB::Util.html_escape(message) % delete_message_data(project).merge(date: date)
    end

    def delete_delayed_message(project)
      date = permanent_deletion_date_formatted(project, Time.now.utc)

      if project.feature_available?(:adjourned_deletion_for_projects_and_groups)
        message = _("This action will place this project, including all its resources, in a pending deletion state for %{deletion_adjourned_period} days, and delete it permanently on %{strongOpen}%{date}%{strongClose}.")
        ERB::Util.html_escape(message) % delete_message_data(project).merge(date: date, deletion_adjourned_period: deletion_adjourned_period)
      else
        # This is a free project, it will use delayed deletion but can only be restored by an admin.
        _('This action will permanently delete this project, including all its resources.')
      end
    end

    def permanent_deletion_date_formatted(project, date)
      project.permanent_deletion_date(date).strftime('%F')
    end

    # Given the current GitLab configuration, check whether the GitLab URL for Kerberos is going to be different than the HTTP URL
    def alternative_kerberos_url?
      ::Gitlab.config.alternative_gitlab_kerberos_url?
    end

    def can_change_push_rule?(push_rule, rule, context)
      return true if push_rule.global?

      can?(current_user, :"change_#{rule}", context)
    end

    def ci_cd_projects_available?
      ::License.feature_available?(:ci_cd_projects) && import_sources_enabled?
    end

    def show_archived_project_banner?(project)
      return false if project&.marked_for_deletion?

      super
    end

    def show_pending_deletion_project_banner?(project)
      return false unless project.present? && project.saved?

      project.marked_for_deletion?
    end

    override :remote_mirror_setting_enabled?
    def remote_mirror_setting_enabled?
      ::Gitlab::CurrentSettings.import_sources.any? &&
        ::License.feature_available?(:ci_cd_projects) &&
        (::Gitlab::CurrentSettings.current_application_settings.mirror_available || current_user.can_admin_all_resources?)
    end

    def merge_pipelines_available?
      return false unless @project.builds_enabled?

      @project.feature_available?(:merge_pipelines)
    end

    def merge_trains_available?(project)
      return false unless project.builds_enabled?

      project.feature_available?(:merge_trains)
    end

    def size_limit_message(project)
      repository_size_limit_link = link_to _('Learn more'), help_page_path('administration/settings/account_and_limit_settings.md', anchor: 'repository-size-limit')
      message = project.lfs_enabled? ? _("Max size of this project's repository, including LFS files. %{repository_size_limit_link}.") : _("Max size of this project's repository. %{repository_size_limit_link}.")

      safe_format(message, repository_size_limit_link: repository_size_limit_link)
    end

    override :membership_locked?
    def membership_locked?
      group = @project.group

      return false unless group

      group.membership_lock? ||
        ::Gitlab::CurrentSettings.lock_memberships_to_ldap? ||
        ::Gitlab::CurrentSettings.lock_memberships_to_saml?
    end

    def group_project_templates_count(group_id)
      if ::Feature.enabled?(:project_templates_without_min_access, current_user)
        preloaded_projects(group_id).count do |project|
          can?(current_user, :download_code, project)
        end
      else
        projects_not_aimed_for_deletions_for(group_id).count
      end
    end

    def group_project_templates(group)
      if ::Feature.enabled?(:project_templates_without_min_access, current_user)
        preloaded_projects(group.id).select do |project|
          can?(current_user, :download_code, project)
        end
      else
        group.projects.not_aimed_for_deletion.non_archived
      end
    end

    def base_project_security_dashboard_config(project)
      {
        has_vulnerabilities: 'false',
        has_jira_vulnerabilities_integration_enabled: project.configured_to_create_issues_from_vulnerabilities?.to_s,
        empty_state_svg_path: image_path('illustrations/empty-state/empty-secure-md.svg'),
        security_dashboard_empty_svg_path: image_path('illustrations/empty-state/empty-secure-md.svg'),
        no_vulnerabilities_svg_path: image_path('illustrations/empty-state/empty-search-md.svg'),
        project: { id: project.id, name: project.name },
        project_full_path: project.full_path,
        security_configuration_path: project_security_configuration_path(@project),
        can_admin_vulnerability: can?(current_user, :admin_vulnerability, project).to_s,
        new_vulnerability_path: new_project_security_vulnerability_path(@project),
        dismissal_descriptions: dismissal_descriptions.to_json,
        hide_third_party_offers: ::Gitlab::CurrentSettings.current_application_settings.hide_third_party_offers?.to_s,
        operational_configuration_path: new_project_security_policy_path(@project)
      }.merge(security_dashboard_pipeline_data(project))
    end

    def project_security_dashboard_config_with_vulnerabilities(project)
      base_project_security_dashboard_config(project).merge(
        {
          has_vulnerabilities: 'true',
          vulnerabilities_export_endpoint: expose_path(api_v4_security_projects_vulnerability_exports_path(id: project.id)),
          new_project_pipeline_path: new_project_pipeline_path(project),
          scanners: VulnerabilityScanners::ListService.new(project).execute.to_json,
          can_view_false_positive: can_view_false_positive?,
          vulnerability_quota: vulnerability_quota_information(project)
        }
      )
    end

    def project_security_dashboard_config(project)
      has_vulnerabilities = project.vulnerabilities.exists?

      return project_security_dashboard_config_with_vulnerabilities(project) if has_vulnerabilities

      base_project_security_dashboard_config(project)
    end

    def can_view_false_positive?
      project.licensed_feature_available?(:sast_fp_reduction).to_s
    end

    def can_create_feedback?(project, feedback_type)
      feedback = Vulnerabilities::Feedback.new(project: project, feedback_type: feedback_type)
      can?(current_user, :create_vulnerability_feedback, feedback)
    end

    def create_vulnerability_feedback_issue_path(project)
      if can_create_feedback?(project, :issue)
        project_vulnerability_feedback_index_path(project)
      end
    end

    def create_vulnerability_feedback_merge_request_path(project)
      if can_create_feedback?(project, :merge_request)
        project_vulnerability_feedback_index_path(project)
      end
    end

    def create_vulnerability_feedback_dismissal_path(project)
      if can_create_feedback?(project, :dismissal)
        project_vulnerability_feedback_index_path(project)
      end
    end

    def show_discover_project_security?(project)
      !!current_user &&
        ::Gitlab.com? &&
        !project.feature_available?(:security_dashboard) &&
        can?(current_user, :admin_namespace, project.root_ancestor)
    end

    def show_compliance_frameworks_info?(project)
      project&.licensed_feature_available?(:custom_compliance_frameworks) &&
        project&.compliance_framework_settings&.first&.compliance_management_framework.present?
    end

    def compliance_center_path(project)
      project_security_compliance_dashboard_path(project, vueroute: "frameworks")
    end

    def scheduled_for_deletion?(project)
      project.marked_for_deletion_at.present?
    end

    def project_compliance_framework_app_data(project, can_edit)
      group = project.root_ancestor
      {
        group_name: group.name,
        group_path: group_path(group),
        empty_state_svg_path: image_path('illustrations/welcome/ee_trial.svg')
      }.tap do |data|
        if can_edit
          data[:add_framework_path] = "#{edit_group_path(group)}#js-compliance-frameworks-settings"
        end
      end
    end

    def proxied_site
      ::Gitlab::Geo.proxied_site(request.env)
    end

    override :http_clone_url_to_repo
    def http_clone_url_to_repo(project)
      proxied_site ? geo_proxied_http_url_to_repo(proxied_site, project) : super
    end

    override :ssh_clone_url_to_repo
    def ssh_clone_url_to_repo(project)
      proxied_site ? geo_proxied_ssh_url_to_repo(proxied_site, project) : super
    end

    def project_transfer_app_data(project)
      {
        full_path: project.full_path
      }
    end

    def product_analytics_settings_allowed?(project)
      return false unless project.product_analytics_enabled?
      return false unless can?(current_user, :modify_product_analytics_settings, project)

      true
    end

    def compliance_framework_data_attributes(project)
      return {} unless show_compliance_frameworks_info?(project)

      framework_data = {
        has_compliance_framework_feature: License.feature_available?(:compliance_framework).to_s,
        frameworks: []
      }

      framework_settings = project.compliance_framework_settings
      framework_settings.find_each do |settings|
        framework = settings.compliance_management_framework

        framework_data[:frameworks].push({
          compliance_framework_badge_color: framework.color,
          compliance_framework_badge_name: framework.name,
          compliance_framework_badge_title: framework.description
        })
      end

      framework_data
    end

    override :home_panel_data_attributes
    def home_panel_data_attributes
      project = @project.is_a?(ProjectPresenter) ? @project.project : @project

      super.merge(
        is_project_marked_for_deletion: project.marked_for_deletion?.to_s,
        **compliance_framework_data_attributes(project)
      )
    end

    def project_delete_delayed_button_data(project, button_text = nil, is_security_policy_project: false)
      project_delete_button_shared_data(project, button_text).merge({
        is_security_policy_project: is_security_policy_project.to_s,
        restore_help_path: help_page_path('user/project/working_with_projects.md', anchor: 'restore-a-project'),
        delayed_deletion_date: permanent_deletion_date_formatted(project, Time.now.utc).to_s,
        form_path: project_path(project)
      })
    end

    def pages_deployments_usage_quota_data(project)
      limit = project.actual_limits.active_versioned_pages_deployments_limit_by_namespace
      project_deployments_count = ::PagesDeployment.count_versioned_deployments_for(project, limit)
      deployments_count = if project.pages_unique_domain_enabled?
                            project_deployments_count
                          else
                            ::PagesDeployment.count_versioned_deployments_for(
                              project.root_ancestor.all_projects.with_namespace_domain_pages,
                              limit
                            )
                          end

      {
        full_path: project.full_path,
        deployments_count: deployments_count,
        deployments_limit: limit,
        uses_namespace_domain: (!project.pages_unique_domain_enabled?).to_s,
        project_deployments_count: project_deployments_count,
        domain: ::Gitlab::Pages::UrlBuilder.new(project).hostname
      }
    end

    private

    def security_dashboard_pipeline_data(project)
      pipeline = project.latest_ingested_security_pipeline
      sbom_pipeline = project.latest_ingested_sbom_pipeline

      pipelines = {}

      if pipeline
        pipelines[:pipeline] = {
          id: pipeline.id,
          path: pipeline_path(pipeline),
          created_at: pipeline.created_at.to_fs(:iso8601),
          has_warnings: pipeline.has_security_report_ingestion_warnings?.to_s,
          has_errors: pipeline.has_security_report_ingestion_errors?.to_s,
          security_builds: {
            failed: {
              count: pipeline.latest_failed_security_builds.count,
              path: failures_project_pipeline_path(pipeline.project, pipeline)
            }
          }
        }
      end

      if sbom_pipeline
        pipelines[:sbom_pipeline] = {
          id: sbom_pipeline.id,
          path: pipeline_path(sbom_pipeline),
          created_at: sbom_pipeline.created_at.to_fs(:iso8601),
          has_warnings: "", # Not supported yet
          has_errors: sbom_pipeline.has_sbom_report_ingestion_errors?.to_s
        }
      end

      pipelines
    end

    def vulnerability_quota_information(project)
      {
        full: project.vulnerability_quota.full?.to_s,
        critical: project.vulnerability_quota.critical?.to_s,
        exceeded: project.vulnerability_quota.exceeded?.to_s
      }
    end

    def allowed_subgroups(group_id)
      current_user.available_subgroups_with_custom_project_templates(group_id)
    end

    def projects_not_aimed_for_deletions_for(group_id)
      ::Project
        .with_namespace
        .with_group
        .include_project_feature
        .with_group_saml_provider
        .with_invited_groups
        .in_namespace(allowed_subgroups(group_id))
        .not_aimed_for_deletion
        .non_archived
    end

    def preloaded_projects(group_id)
      projects = projects_not_aimed_for_deletions_for(group_id)

      ::Preloaders::ProjectPolicyPreloader.new(projects, current_user).execute
      ::Preloaders::ProjectRootAncestorPreloader.new(projects).execute

      projects
    end
  end
end
