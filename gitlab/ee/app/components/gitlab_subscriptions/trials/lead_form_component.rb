# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class LeadFormComponent < ViewComponent::Base
      include ::Gitlab::Utils::StrongMemoize
      include SafeFormatHelper

      # @param [Namespaces] eligible_namespaces
      # @param [User] user
      # @param [Submit Path] submit_path for the form
      # @param [Form Params] form params for the form on submission failure

      def initialize(**kwargs)
        @user = kwargs[:user]
        @namespace_id = kwargs[:namespace_id]
        @eligible_namespaces = kwargs[:eligible_namespaces]
        @submit_path = kwargs[:submit_path]
      end

      private

      attr_reader :user, :namespace_id, :eligible_namespaces, :submit_path

      delegate :page_title, to: :helpers

      def before_form_content
        # no-op
      end

      def title_text
        group_name ? group_trial_title : default_trial_title
      end

      def group_trial_title
        safe_format(
          s_('Trial|Start your free Ultimate and GitLab Duo Enterprise trial on %{group_name}'),
          group_name: group_name
        )
      end

      def default_trial_title
        s_('Trial|Start your free Ultimate and GitLab Duo Enterprise trial')
      end

      def group_name
        (namespace_in_params || single_eligible_namespace)&.name
      end
      strong_memoize_attr :group_name

      def single_eligible_namespace
        return unless GitlabSubscriptions::Trials.single_eligible_namespace?(eligible_namespaces)

        eligible_namespaces.first
      end

      def namespace_in_params
        return unless namespace_id

        eligible_namespaces.find_by_id(namespace_id)
      end

      def form_data
        {
          first_name: user.first_name,
          last_name: user.last_name,
          email_domain: user.email_domain,
          company_name: user.organization,
          submit_button_text: submit_text,
          submit_path: submit_path
        }
      end

      def submit_text
        if GitlabSubscriptions::Trials.single_eligible_namespace?(eligible_namespaces)
          s_('Trial|Activate my trial')
        else
          s_('Trial|Continue')
        end
      end
    end
  end
end
