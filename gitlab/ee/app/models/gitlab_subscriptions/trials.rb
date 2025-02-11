# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    def self.single_eligible_namespace?(eligible_namespaces)
      return false unless eligible_namespaces.any? # executes query and now relation is loaded

      eligible_namespaces.count == 1
    end

    def self.creating_group_trigger?(namespace_id)
      # The value of 0 is the option in the select for creating a new group
      namespace_id.to_s == '0'
    end

    def self.eligible_namespace?(namespace_id, eligible_namespaces)
      return true if namespace_id.blank?

      namespace_id.to_i.in?(eligible_namespaces.pluck_primary_key)
    end

    def self.namespace_eligible?(namespace)
      namespace_plan_eligible?(namespace) && namespace_add_on_eligible?(namespace)
    end

    def self.namespace_plan_eligible?(namespace)
      namespace.actual_plan_name.in?(::Plan::PLANS_ELIGIBLE_FOR_TRIAL)
    end

    def self.namespace_plan_eligible_for_active?(namespace)
      namespace.actual_plan_name.in?(::Plan::ULTIMATE_TRIAL_PLANS)
    end

    def self.namespace_add_on_eligible?(namespace)
      Namespaces::TrialEligibleFinder.new(namespace: namespace).execute.any?
    end

    def self.namespace_with_mid_trial_premium?(namespace, trial_starts_on)
      return false unless namespace.premium_plan?

      namespace.gitlab_subscription_histories.transitioning_to_plan_after(
        ::Plan.by_name(::Plan::PREMIUM),
        trial_starts_on
      ).exists?
    end
  end
end
