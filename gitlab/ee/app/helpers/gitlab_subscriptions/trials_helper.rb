# frozen_string_literal: true

module GitlabSubscriptions
  module TrialsHelper
    def create_duo_pro_lead_form_data(eligible_namespaces)
      submit_path = trials_duo_pro_path(
        step: GitlabSubscriptions::Trials::CreateDuoProService::LEAD,
        namespace_id: params[:namespace_id]
      )

      _lead_form_data(eligible_namespaces).merge(submit_path: submit_path)
    end

    def create_duo_enterprise_lead_form_data(eligible_namespaces)
      submit_path = trials_duo_enterprise_path(
        step: GitlabSubscriptions::Trials::CreateDuoEnterpriseService::LEAD,
        namespace_id: params[:namespace_id]
      )

      _lead_form_data(eligible_namespaces).merge(submit_path: submit_path)
    end

    def duo_trial_namespace_selector_data(namespaces, namespace_create_errors)
      namespace_selector_data(namespace_create_errors).merge(
        any_trial_eligible_namespaces: namespaces.any?.to_s,
        items: current_namespaces_for_selector(namespaces).to_json
      )
    end

    def glm_source
      ::Gitlab.config.gitlab.host
    end

    def show_tier_badge_for_new_trial?(namespace, user)
      ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
        !namespace.paid? &&
        namespace.private? &&
        namespace.never_had_trial? &&
        can?(user, :read_billing, namespace)
    end

    def trial_form_errors_message(result)
      unless result.reason == GitlabSubscriptions::Trials::BaseApplyTrialService::GENERIC_TRIAL_ERROR
        return result.errors.to_sentence
      end

      safe_format(
        errors_message(result.errors),
        tag_pair(support_link, :support_link_start, :support_link_end)
      )
    end

    private

    def support_link
      link_to('', Gitlab::Saas.customer_support_url, target: '_blank', rel: 'noopener noreferrer')
    end

    def errors_message(errors)
      support_message = _('Please reach out to %{support_link_start}GitLab Support%{support_link_end} for assistance')
      full_message = [support_message, errors.to_sentence.presence].compact.join(': ')

      "#{full_message}."
    end

    def trial_submit_text(eligible_namespaces)
      if GitlabSubscriptions::Trials.single_eligible_namespace?(eligible_namespaces)
        s_('Trial|Activate my trial')
      else
        s_('Trial|Continue')
      end
    end

    def current_namespaces_for_selector(namespaces)
      namespaces.map { |n| { text: n.name, value: n.id.to_s } }
    end

    def _lead_form_data(eligible_namespaces)
      {
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        email_domain: current_user.email_domain,
        company_name: current_user.organization,
        submit_button_text: trial_submit_text(eligible_namespaces)
      }.merge(
        params.permit(
          :first_name, :last_name, :company_name, :company_size, :phone_number, :country, :state
        ).to_h.symbolize_keys
      )
    end

    def namespace_selector_data(namespace_create_errors)
      {
        new_group_name: params[:new_group_name],
        # This may allow through an unprivileged submission of trial since we don't validate access on the passed in
        # namespace_id.
        # That is ok since we validate this on submission.
        initial_value: params[:namespace_id],
        namespace_create_errors: namespace_create_errors
      }
    end
  end
end
