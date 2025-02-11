# frozen_string_literal: true

module Namespaces
  class TrialEligibleFinder
    include Gitlab::Utils::StrongMemoize

    EXPIRATION_TIME = 8.hours

    def initialize(params = {})
      @params = params
    end

    def execute
      if params[:use_caching]
        raise ArgumentError, 'Trial types must be provided' unless params[:trials]

        namespaces = scope_by_plans
        @namespace_ids = namespaces.map(&:id)
        return Namespace.none if @namespace_ids.empty?

        namespaces.id_in(find_eligible_namespace_ids).ordered_by_name
      else
        filter_by_duo_enterprise_eligibility.ordered_by_name
      end
    end

    private

    attr_reader :params, :namespace_ids

    def scope_by_plans(plans = nil)
      if params[:user] && params[:namespace]
        raise ArgumentError, 'Only User or Namespace can be provided, not both'
      elsif params[:user]
        plans ? params[:user].owned_groups.in_specific_plans(plans) : params[:user].owned_groups
      elsif params[:namespace]
        Namespace.id_in(params[:namespace])
      else
        raise ArgumentError, 'User or Namespace must be provided'
      end
    end

    def no_subscription_plan_name
      # Subscriptions aren't created until needed/looked at
      nil
    end

    def filter_by_duo_enterprise_eligibility
      premium_namespaces = scope_by_plans(::Plan::PREMIUM)

      # Get the subscription history that was created the last time this namespace left
      # the free plan.
      latest_history = GitlabSubscriptions::SubscriptionHistory
                         .latest_updated_history_by_hosted_plan_id(
                           ::Plan.by_name(::Plan::FREE).select(:id), premium_namespaces.select(:id)
                         )

      # Allow premium namespaces to start a new Ultimate + Duo Enterprise trial if:
      # 1. Their last trial was when they were on a free plan
      # 2. They had a Duo Enterprise add-on before upgrading to Premium
      #
      # Rationale:
      # - We assume Duo Enterprise on a free plan was always part of a trial
      # - We don't need to check if the add-on was a trial, as this info is transient
      # - This logic may allow some edge cases (e.g., Ultimate -> Free -> Premium),
      #   but these will be addressed in https://gitlab.com/groups/gitlab-org/-/epics/16169
      #
      # Note: This approach ensures eligibility for another Ultimate + Duo Enterprise trial
      #       for customers who have upgraded from free to premium plans.
      allowing_another_trial =
        premium_namespaces
          .by_subscription_history_for_expired_duo_enterprise_add_on(latest_history)
          .id_not_in(
            GitlabSubscriptions::AddOnPurchase
              .by_add_on_name('code_suggestions')
              .trial
              .active
              .by_namespace(premium_namespaces)
              .select(:namespace_id)
          ).select(:id)

      Namespace.id_in(Namespace.from_union(base_qualifications, allowing_another_trial).select(:id))
    end

    def base_qualifications
      scope_by_plans([no_subscription_plan_name, *::Plan::PLANS_ELIGIBLE_FOR_TRIAL])
        .not_duo_enterprise_or_no_add_on.no_active_duo_pro_trial.select(:id)
    end

    def find_eligible_namespace_ids
      if cache_exists?
        cached_eligible_namespace_ids
      else
        cache_eligible_namespace_ids
      end
    end

    def client
      Gitlab::SubscriptionPortal::Client
    end

    def cache_key(id)
      "namespaces:eligible_trials:#{id}"
    end

    def cache_keys
      namespace_ids.map { |id| cache_key(id) }
    end
    strong_memoize_attr :cache_keys

    def cache_exists?
      cache_keys.all? { |key| Rails.cache.exist?(key) }
    end

    def filter_namespace_ids(id_trials_hash)
      id_trials_hash.select { |_, trials| (trials & params[:trials]).sort == params[:trials].sort }.keys
    end

    def cached_eligible_namespace_ids
      values = Rails.cache.read_multi(*cache_keys).values
      filter_namespace_ids(Hash[namespace_ids.zip(values)])
    end

    def eligible_trials_request
      response = client.namespace_eligible_trials(namespace_ids: namespace_ids)

      if response[:success]
        response.dig(:data, :namespaces)
      else
        Gitlab::AppLogger.warn(
          class: self.class.name,
          message: 'Unable to fetch eligible trials from GitLab Customers App',
          error_message: response.dig(:data, :errors)
        )

        {}
      end
    end

    def cache_eligible_namespace_ids
      response_data = eligible_trials_request
      return [] if response_data.blank?

      Rails.cache.write_multi(
        response_data.transform_keys { |id| cache_key(id) },
        expires_in: EXPIRATION_TIME
      )

      filter_namespace_ids(response_data)
    end
  end
end
