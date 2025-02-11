# frozen_string_literal: true

module Registrations
  class WelcomeController < ApplicationController
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include GoogleSyndicationCSP
    include ::Gitlab::Utils::StrongMemoize
    include ::Onboarding::Redirectable
    include ::Onboarding::SetRedirect
    include ::Onboarding::InProgress

    layout 'minimal'

    before_action :verify_onboarding_enabled!
    before_action only: :show do
      set_onboarding_status_params
      verify_welcome_needed!
    end

    before_action :verify_in_onboarding_flow!
    before_action :set_update_onboarding_status_params, only: :update

    helper_method :onboarding_status_presenter

    feature_category :onboarding

    def show; end

    def update
      result = ::Users::SignupService
                 .new(current_user, user_return_to: session['user_return_to'], params: update_params).execute

      if result.success?
        clear_memoization(:onboarding_status_presenter) # needed in case registration_type is changed on update
        track_event('successfully_submitted_form')
        track_joining_a_project_event

        redirect_to update_success_path
      else
        track_event("track_#{onboarding_status_presenter.tracking_label}_error", label: 'failed_submitting_form')

        render :show
      end
    end

    private

    def authenticate_user!
      return if current_user

      redirect_to new_user_registration_path
    end

    def set_onboarding_status_params
      @onboarding_status_params = {}
    end

    def verify_welcome_needed!
      return unless completed_welcome_step?

      redirect_to path_for_signed_in_user
    end

    def completed_welcome_step?
      !current_user.setup_for_company.nil?
    end

    def update_params
      base_params = params
                      .require(:user)
                      .permit(
                        :role,
                        :setup_for_company,
                        :registration_objective,
                        :onboarding_status_joining_project,
                        :onboarding_status_role,
                        :onboarding_status_registration_objective
                      )
                      .merge(params.permit(:jobs_to_be_done_other))
                      .merge(onboarding_registration_type_params)
                      .merge(onboarding_in_progress: onboarding_status_presenter.continue_full_onboarding?)

      # Since onboarding_status_joining_project is not a real db column(jsonb attribute), we need to convert it to
      # boolean at this level.
      base_params[:onboarding_status_joining_project] =
        ::Gitlab::Utils.to_boolean(base_params[:onboarding_status_joining_project])

      # Duplicate role information for role and onboarding_status_role
      if base_params[:role].present?
        base_params[:onboarding_status_role] = ::UserDetail.onboarding_status_roles[base_params[:role]]
      else
        base_params[:onboarding_status_role] = base_params[:onboarding_status_role].to_i
        base_params[:role] = ::UserDetail.onboarding_status_roles.key(base_params[:onboarding_status_role])
      end

      # Dup registration_objective info for registration_objective and onboarding_status_registration_objective
      if base_params[:registration_objective].present?
        base_params[:onboarding_status_registration_objective] = base_params[:registration_objective]
      elsif base_params[:onboarding_status_registration_objective].present?
        base_params[:registration_objective] = base_params[:onboarding_status_registration_objective]
      end

      base_params
    end

    def onboarding_registration_type_params
      return {} unless onboarding_status_presenter.convert_to_automatic_trial?

      # Now we are in automatic trial, and we'll update our status as such, initial_registration_type
      # will be how we know if they weren't a trial originally from here on out.
      { onboarding_status_registration_type: ::Onboarding::REGISTRATION_TYPE[:trial] }
    end

    def passed_through_params
      update_params.slice(*::Onboarding::StatusPresenter::PASSED_THROUGH_PARAMS)
    end

    def update_success_path
      if onboarding_status_presenter.continue_full_onboarding? # trials/regular registration on .com
        signup_onboarding_path
      elsif onboarding_status_presenter.single_invite? # invites w/o tasks due to order
        flash[:notice] = helpers.invite_accepted_notice(onboarding_status_presenter.last_invited_member)
        polymorphic_path(onboarding_status_presenter.last_invited_member_source)
      else
        # Subscription registrations goes through here as well.
        # Invites will come here too if there is more than 1.
        path_for_signed_in_user
      end
    end

    def signup_onboarding_path
      if onboarding_status_presenter.joining_a_project?
        Onboarding::FinishService.new(current_user).execute
        path_for_signed_in_user
      elsif onboarding_status_presenter.redirect_to_company_form? # trial only
        Onboarding::StatusStepUpdateService
          .new(current_user, new_users_sign_up_company_path(passed_through_params)).execute[:step_url]
      else
        Onboarding::StatusStepUpdateService.new(current_user, new_users_sign_up_group_path).execute[:step_url]
      end
    end

    def track_joining_a_project_event
      return unless onboarding_status_presenter.joining_a_project?

      cookies[:signup_with_joining_a_project] = { value: true, expires: 30.days }

      track_event('select_button', label: 'join_a_project')
    end

    def track_event(action, label: onboarding_status_presenter.tracking_label)
      ::Gitlab::Tracking.event(
        helpers.body_data_page,
        action,
        user: current_user,
        label: label
      )
    end

    def onboarding_status_presenter
      Onboarding::StatusPresenter.new(@onboarding_status_params, session['user_return_to'], current_user)
    end
    strong_memoize_attr :onboarding_status_presenter

    def set_update_onboarding_status_params
      @onboarding_status_params = params.require(:user).permit(:setup_for_company)
                                        .merge(params.permit(:joining_project)).to_h.deep_symbolize_keys
    end
  end
end

Registrations::WelcomeController.prepend_mod
