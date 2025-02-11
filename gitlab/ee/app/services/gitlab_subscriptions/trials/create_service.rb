# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class CreateService < BaseCreateService
      extend ::Gitlab::Utils::Override

      NAMESPACE_CREATE_FAILED = :namespace_create_failed

      private

      def trial_flow
        if trial_params[:namespace_id].present? &&
            !GitlabSubscriptions::Trials.creating_group_trigger?(trial_params[:namespace_id])
          existing_namespace_flow
        elsif trial_params.key?(:new_group_name)
          create_group_flow
        else
          not_found
        end
      end

      def create_group_flow
        # Instance admins can disable user's ability to create top level groups.
        # See https://docs.gitlab.com/ee/administration/admin_area.html#prevent-a-user-from-creating-groups
        return not_found unless user.can_create_group?

        name = ActionController::Base.helpers.sanitize(trial_params[:new_group_name])
        path = Namespace.clean_path(name.parameterize)
        create_service_params = { name: name, path: path, organization_id: trial_params[:organization_id] }
        response = Groups::CreateService.new(user, create_service_params).execute

        @namespace = response[:group]

        if response.success?
          # We need to stick to the primary database in order to allow the following request
          # fetch the namespace from an up-to-date replica or a primary database.
          ::Namespace.sticking.stick(:namespace, namespace.id)

          apply_trial_flow
        else
          ServiceResponse.error(
            message: namespace.errors.full_messages,
            payload: { namespace_id: trial_params[:namespace_id] },
            reason: NAMESPACE_CREATE_FAILED
          )
        end
      end

      def lead_service_class
        GitlabSubscriptions::CreateLeadService
      end

      def apply_trial_service_class
        GitlabSubscriptions::Trials::ApplyTrialService
      end

      def namespaces_eligible_for_trial
        Namespaces::TrialEligibleFinder.new(user: user).execute
      end

      override :tracking_prefix
      def tracking_prefix
        ''
      end
    end
  end
end
