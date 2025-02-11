# frozen_string_literal: true

# EE:SaaS
module GitlabSubscriptions
  class TrialsController < ApplicationController
    include GitlabSubscriptions::Trials::DuoCommon
    extend ::Gitlab::Utils::Override

    prepend_before_action :authenticate_user! # must run before other before_actions that expect current_user to be set
    before_action :eligible_namespaces # needed when namespace_id isn't provided or is 0(new group)

    feature_category :plan_provisioning
    urgency :low

    def new
      if general_params[:step] == GitlabSubscriptions::Trials::CreateService::TRIAL
        track_event('render_trial_page')

        render GitlabSubscriptions::Trials::TrialFormComponent
                 .new(eligible_namespaces: @eligible_namespaces, params: trial_form_params)
      else
        track_event('render_lead_page')

        render GitlabSubscriptions::Trials::LeadFormComponent
                 .new(
                   user: current_user,
                   namespace_id: general_params[:namespace_id],
                   eligible_namespaces: @eligible_namespaces,
                   submit_path: trial_submit_path
                 )
      end
    end

    def create
      @result = GitlabSubscriptions::Trials::CreateService.new(
        step: general_params[:step], lead_params: lead_params, trial_params: trial_params, user: current_user
      ).execute

      if @result.success?
        # lead and trial created
        # We go off the add on here instead of the subscription for the expiration date since
        # in the premium with ultimate trial case the trial_ends_on does not exist on the
        # gitlab_subscription record.
        flash[:success] = success_flash_message(@result.payload[:add_on_purchase])

        redirect_to trial_success_path(@result.payload[:namespace])
      elsif @result.reason == GitlabSubscriptions::Trials::CreateService::NO_SINGLE_NAMESPACE
        # lead created, but we now need to select namespace and then apply a trial
        redirect_to new_trial_path(@result.payload[:trial_selection_params])
      elsif @result.reason == GitlabSubscriptions::Trials::CreateService::NOT_FOUND
        # namespace not found/not permitted to create
        render_404
      elsif @result.reason == GitlabSubscriptions::Trials::CreateService::LEAD_FAILED
        render GitlabSubscriptions::Trials::LeadFormWithErrorsComponent
                 .new(
                   user: current_user,
                   namespace_id: general_params[:namespace_id],
                   eligible_namespaces: @eligible_namespaces,
                   submit_path: trial_submit_path,
                   form_params: lead_form_params,
                   errors: @result.errors
                 )
      elsif @result.reason == GitlabSubscriptions::Trials::CreateService::NAMESPACE_CREATE_FAILED
        # namespace creation failed
        params[:namespace_id] = @result.payload[:namespace_id] # rubocop:disable Rails/StrongParams -- Not working for assignment

        render GitlabSubscriptions::Trials::TrialFormComponent
                 .new(
                   eligible_namespaces: @eligible_namespaces,
                   params: trial_form_params,
                   namespace_create_errors: @result.errors.to_sentence
                 )
      else
        # trial creation failed
        params[:namespace_id] = @result.payload[:namespace_id] # rubocop:disable Rails/StrongParams -- Not working for assignment

        render GitlabSubscriptions::Trials::TrialFormWithErrorsComponent
                 .new(
                   eligible_namespaces: @eligible_namespaces,
                   params: trial_form_params,
                   reason: @result.reason,
                   errors: @result.errors
                 )
      end
    end

    private

    def trial_submit_path
      trials_path(
        step: GitlabSubscriptions::Trials::CreateService::LEAD,
        **params.permit(*::Onboarding::StatusPresenter::GLM_PARAMS, :namespace_id)
      )
    end

    def lead_form_params
      params.permit(
        :first_name, :last_name, :company_name, :company_size, :phone_number, :country, :state
      ).to_h.symbolize_keys
    end

    def trial_form_params
      ::Onboarding::StatusPresenter.glm_tracking_params(params).merge(params.permit(:new_group_name, :namespace_id)) # rubocop:disable Rails/StrongParams -- method performs strong params
    end

    def trial_success_path(namespace)
      if discover_group_security_flow?
        group_security_dashboard_path(namespace)
      else
        group_settings_gitlab_duo_path(namespace)
      end
    end

    def authenticate_user!
      return if current_user

      redirect_to(
        new_trial_registration_path(::Onboarding::StatusPresenter.glm_tracking_params(params)), # rubocop:disable Rails/StrongParams -- method performs strong params
        alert: I18n.t('devise.failure.unauthenticated')
      )
    end

    def trial_params
      params.permit(*::Onboarding::StatusPresenter::GLM_PARAMS, :new_group_name, :namespace_id)
      .with_defaults(organization_id: Current.organization_id).to_h
    end

    def eligible_namespaces
      @eligible_namespaces = Namespaces::TrialEligibleFinder.new(user: current_user).execute
    end

    def discover_group_security_flow?
      %w[discover-group-security discover-project-security].include?(trial_params[:glm_content])
    end

    def should_check_eligibility?
      namespace_id = general_params[:namespace_id]
      namespace_id.present? && !GitlabSubscriptions::Trials.creating_group_trigger?(namespace_id)
    end

    override :eligible_for_trial?
    def eligible_for_trial?
      !should_check_eligibility? || namespace_in_params_eligible?
    end

    def success_flash_message(add_on_purchase)
      if discover_group_security_flow?
        s_("BillingPlans|Congratulations, your free trial is activated.")
      else
        safe_format(
          s_(
            "BillingPlans|You have successfully started an Ultimate and GitLab Duo Enterprise trial that will " \
              "expire on %{exp_date}. " \
              "To give members access to new GitLab Duo Enterprise features, " \
              "%{assign_link_start}assign them%{assign_link_end} to GitLab Duo Enterprise seats."
          ),
          success_doc_link,
          exp_date: l(add_on_purchase.expires_on.to_date, format: :long)
        )
      end
    end
  end
end

GitlabSubscriptions::TrialsController.prepend_mod
