# frozen_string_literal: true

# EE:SaaS
module GitlabSubscriptions
  module Trials
    class DuoProController < ApplicationController
      include GitlabSubscriptions::Trials::DuoCommon

      feature_category :subscription_management
      urgency :low

      def new
        if general_params[:step] == GitlabSubscriptions::Trials::CreateDuoProService::TRIAL
          track_event('render_duo_pro_trial_page')

          render :step_namespace
        else
          set_group_name
          track_event('render_duo_pro_lead_page')

          render :step_lead
        end
      end

      def create
        @result = GitlabSubscriptions::Trials::CreateDuoProService.new(
          step: general_params[:step], lead_params: lead_params, trial_params: trial_params, user: current_user
        ).execute

        if @result.success?
          # lead and trial created
          flash[:success] = success_flash_message(@result.payload[:add_on_purchase])

          redirect_to group_settings_gitlab_duo_path(@result.payload[:namespace])
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoProService::NO_SINGLE_NAMESPACE
          # lead created, but we now need to select namespace and then apply a trial
          redirect_to new_trials_duo_pro_path(@result.payload[:trial_selection_params])
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoProService::NOT_FOUND
          # namespace not found/not permitted to create
          render_404
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoProService::LEAD_FAILED
          set_group_name

          render :step_lead_failed
        else
          # trial creation failed
          params[:namespace_id] = @result.payload[:namespace_id] # rubocop:disable Rails/StrongParams -- Not working for assignment

          render :trial_failed
        end
      end

      private

      def eligible_namespaces
        @eligible_namespaces = Users::AddOnTrialEligibleNamespacesFinder.new(current_user, add_on: :duo_pro).execute
      end
      strong_memoize_attr :eligible_namespaces

      def trial_params
        params.permit(*::Onboarding::StatusPresenter::GLM_PARAMS, :namespace_id).to_h
      end

      def success_flash_message(add_on_purchase)
        safe_format(
          s_(
            'DuoProTrial|You have successfully started a Duo Pro trial that will ' \
              'expire on %{exp_date}. To give members access to new GitLab Duo Pro features, ' \
              '%{assign_link_start}assign them%{assign_link_end} to GitLab Duo Pro seats.'
          ),
          success_doc_link,
          exp_date: l(add_on_purchase.expires_on.to_date, format: :long)
        )
      end
    end
  end
end
