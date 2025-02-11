# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class TrialFormComponent < ViewComponent::Base
      # @param [Form Params] form params for the form on submission failure

      def initialize(**kwargs)
        @eligible_namespaces = kwargs[:eligible_namespaces]
        @params = kwargs[:params]
        @namespace_create_errors = kwargs[:namespace_create_errors]
      end

      private

      attr_reader :eligible_namespaces, :params, :namespace_create_errors

      delegate :page_title, to: :helpers

      def before_form_content
        # no-op
      end

      def submit_path
        trials_path(**::Onboarding::StatusPresenter.glm_tracking_attributes(params),
                    step: GitlabSubscriptions::Trials::CreateService::TRIAL)
      end

      def title_text
        if eligible_namespaces.any?
          s_('Trial|Apply your trial to a new or existing group')
        else
          s_('Trial|Apply your trial to a new group')
        end
      end

      def trial_selection_intro_text
        if eligible_namespaces.any?
          s_('Trials|You can apply your trial of Ultimate with GitLab Duo Enterprise to a group.')
        else
          s_('Trials|Create a new group and start your trial of Ultimate with GitLab Duo Enterprise.')
        end
      end

      def trial_namespace_selector_data
        namespace_selector_data.merge(
          any_trial_eligible_namespaces: eligible_namespaces.any?.to_s,
          items: namespace_options_for_listbox.to_json
        )
      end

      def namespace_selector_data
        {
          new_group_name: params[:new_group_name],
          # This may allow through an unprivileged submission of trial since we don't validate access on the passed in
          # namespace_id.
          # That is ok since we validate this on submission.
          initial_value: params[:namespace_id],
          namespace_create_errors: namespace_create_errors
        }
      end

      def namespace_options_for_listbox
        group_options = current_namespaces_for_selector
        options = [
          {
            text: _('New'),
            options: [
              {
                text: _('Create group'),
                value: '0'
              }
            ]
          }
        ]

        options.push(text: _('Groups'), options: group_options) unless group_options.empty?

        options
      end

      def current_namespaces_for_selector
        eligible_namespaces.map { |n| { text: n.name, value: n.id.to_s } }
      end
    end
  end
end
