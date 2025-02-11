# frozen_string_literal: true

module EE
  module Users
    module CalloutsHelper
      extend ::Gitlab::Utils::Override

      TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK = 'two_factor_auth_recovery_settings_check'
      ACTIVE_USER_COUNT_THRESHOLD = 'active_user_count_threshold'
      GEO_ENABLE_HASHED_STORAGE = 'geo_enable_hashed_storage'
      GEO_MIGRATE_HASHED_STORAGE = 'geo_migrate_hashed_storage'
      ULTIMATE_TRIAL = 'ultimate_trial'
      NEW_USER_SIGNUPS_CAP_REACHED = 'new_user_signups_cap_reached'
      PERSONAL_ACCESS_TOKEN_EXPIRY = 'personal_access_token_expiry'
      PROFILE_PERSONAL_ACCESS_TOKEN_EXPIRY = 'profile_personal_access_token_expiry'
      JOINING_A_PROJECT_ALERT = 'joining_a_project_alert'
      PIPL_COMPLIANCE_ALERT = 'pipl_compliance_alert'

      override :render_dashboard_ultimate_trial
      def render_dashboard_ultimate_trial(user)
        return unless show_ultimate_trial?(user, ULTIMATE_TRIAL) &&
          user_default_dashboard?(user) &&
          !user.owns_paid_namespace? &&
          user.owns_group_without_trial?

        render 'shared/ultimate_with_enterprise_trial_callout_content'
      end

      def render_two_factor_auth_recovery_settings_check
        return unless current_user &&
          ::Gitlab.com? &&
          current_user.two_factor_otp_enabled? &&
          !user_dismissed?(TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK, 3.months.ago)

        render 'shared/two_factor_auth_recovery_settings_check'
      end

      def show_pipl_compliance_alert?
        ::Gitlab::Saas.feature_available?(:pipl_compliance) &&
          !user_dismissed?(PIPL_COMPLIANCE_ALERT) &&
          ::ComplianceManagement::Pipl.user_subject_to_pipl?(current_user) &&
          ::Feature.enabled?(:enforce_pipl_compliance, current_user) &&
          current_user.pipl_user.initial_email_sent_at.present?
      end

      def show_new_user_signups_cap_reached?
        return false unless current_user&.can_admin_all_resources?
        return false if user_dismissed?(NEW_USER_SIGNUPS_CAP_REACHED)
        return false unless ::Gitlab::CurrentSettings.seat_control_user_cap?

        new_user_signups_cap = ::Gitlab::CurrentSettings.new_user_signups_cap

        new_user_signups_cap.to_i <= ::User.billable.count
      end

      override :dismiss_two_factor_auth_recovery_settings_check
      def dismiss_two_factor_auth_recovery_settings_check
        ::Users::DismissCalloutService.new(
          container: nil, current_user: current_user, params: { feature_name: TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK }
        ).execute
      end

      def show_joining_a_project_alert?
        return false unless cookies[:signup_with_joining_a_project]
        return false unless ::Gitlab::Saas.feature_available?(:onboarding)

        !user_dismissed?(JOINING_A_PROJECT_ALERT)
      end

      override :show_transition_to_jihu_callout?
      def show_transition_to_jihu_callout?
        !gitlab_com_subscription? && !has_active_license? && super
      end

      private

      override :dismissed_callout?
      def dismissed_callout?(object, query)
        return super if object.is_a?(Project)

        current_user.dismissed_callout_for_group?(group: object, **query)
      end

      def hashed_storage_enabled?
        ::Gitlab::CurrentSettings.current_application_settings.hashed_storage_enabled
      end

      def show_ultimate_trial?(user, callout = ULTIMATE_TRIAL)
        return false unless user
        return false unless show_ultimate_trial_suitable_env?
        return false if user_dismissed?(callout)

        true
      end

      def show_ultimate_trial_suitable_env?
        ::Gitlab.com? && !::Gitlab::Database.read_only?
      end
    end
  end
end
