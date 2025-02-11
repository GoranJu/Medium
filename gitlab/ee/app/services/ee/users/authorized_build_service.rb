# frozen_string_literal: true

module EE
  module Users
    module AuthorizedBuildService
      extend ::Gitlab::Utils::Override

      PROVIDERS_ALLOWED_TO_SKIP_CONFIRMATION = [::Users::BuildService::GROUP_SCIM_PROVIDER,
        ::Users::BuildService::GROUP_SAML_PROVIDER].freeze

      override :initialize
      def initialize(current_user, params = nil)
        super

        set_skip_confirmation_param
      end

      private

      override :signup_params
      def signup_params
        base_params = super + [:provisioned_by_group_id]

        return base_params unless ::Onboarding.enabled?

        # TrialRegistrationsController and OmniAuthCallbacksController both pass an onboarding_status_email_opt_in
        # param so we need to be sure to allow it here.
        base_params + [:onboarding_status_email_opt_in]
      end

      def group
        return unless params[:group_id]

        strong_memoize(:group) do
          ::Group.find(params[:group_id])
        end
      end

      def set_skip_confirmation_param
        return if params[:skip_confirmation] # Explicit skip confirmation passed as param
        return unless PROVIDERS_ALLOWED_TO_SKIP_CONFIRMATION.include?(params[:provider])

        return unless params[:email] && ValidateEmail.valid?(params[:email])

        params[:skip_confirmation] = true if group&.owner_of_email?(params[:email])
      end
    end
  end
end
