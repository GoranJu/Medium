# frozen_string_literal: true

module Onboarding
  REGISTRATION_TYPE = {
    free: 'free',
    trial: 'trial',
    invite: 'invite',
    subscription: 'subscription'
  }.freeze

  def self.enabled?
    ::Gitlab::Saas.feature_available?(:onboarding)
  end

  def self.user_onboarding_in_progress?(user)
    user.present? &&
      user.onboarding_in_progress? &&
      enabled?
  end

  def self.add_on_seat_assignment_iterable_params(user, product_interaction, namespace)
    {
      first_name: user.first_name,
      last_name: user.last_name,
      work_email: user.email,
      namespace_id: namespace.id,
      product_interaction: product_interaction,
      existing_plan: namespace.actual_plan_name,
      opt_in: user.onboarding_status_email_opt_in,
      preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language)
    }.stringify_keys
  end
end
