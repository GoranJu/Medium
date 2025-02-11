# frozen_string_literal: true

module Ai
  module UserAuthorizable
    extend ActiveSupport::Concern

    GROUP_WITH_AI_ENABLED_CACHE_PERIOD = 1.hour
    GROUP_WITH_AI_ENABLED_CACHE_KEY = 'group_with_ai_enabled'
    GROUP_WITH_GA_AI_ENABLED_CACHE_KEY = 'group_with_ga_ai_enabled'

    GROUP_IDS_WITH_AI_CHAT_ENABLED_CACHE_KEY = 'group_ids_with_ai_chat_enabled'
    GROUP_IDS_WITH_AI_CHAT_ENABLED_CACHE_PERIOD = 1.hour

    DUO_PRO_ADD_ON_CACHE_KEY = 'user-%{user_id}-code-suggestions-add-on-cache'
    # refers to add-ons listed in GitlabSubscriptions::AddOn::DUO_ADD_ONS
    DUO_ADD_ONS_CACHE_KEY = 'user-%{user_id}-duo-add-ons-cache'

    Response = Struct.new(:allowed?, :namespace_ids, :enablement_type, keyword_init: true)

    included do
      def duo_pro_add_on_available_namespace_ids
        cache_key = format(DUO_PRO_ADD_ON_CACHE_KEY, user_id: id)

        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          GitlabSubscriptions::UserAddOnAssignment.by_user(self).for_active_gitlab_duo_pro_purchase
            .pluck('subscription_add_on_purchases.namespace_id') # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's purchases
        end
      end

      def duo_available_namespace_ids
        cache_key = duo_addons_cache_key_formatted

        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          GitlabSubscriptions::UserAddOnAssignment.by_user(self).for_active_gitlab_duo_purchase
            .pluck('subscription_add_on_purchases.namespace_id') # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's purchases
            .uniq
        end
      end

      def duo_addons_cache_key_formatted
        format(DUO_ADD_ONS_CACHE_KEY, user_id: id)
      end

      def duo_pro_cache_key_formatted
        self.class.duo_pro_cache_key_formatted(id)
      end

      def eligible_for_self_managed_gitlab_duo_pro?
        return false if gitlab_com_subscription?

        active? && !bot? && !ghost?
      end

      # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's groups
      def billable_gitlab_duo_pro_root_group_ids
        return unless gitlab_com_subscription?

        group_ids_from_project_authorizaton = Project.where(id: project_authorizations.non_guests.select(:project_id))
          .pluck(:namespace_id)
        group_ids_from_memberships = GroupMember.with_user(self).active.non_guests.pluck(:source_id)
        group_ids_from_linked_groups = GroupGroupLink.non_guests.where(shared_with_group_id: group_ids_from_memberships)
          .pluck(:shared_group_id)

        Group.where(
          id: group_ids_from_project_authorizaton | group_ids_from_memberships | group_ids_from_linked_groups
        ).pluck(Arel.sql('traversal_ids[1]')).uniq
      end
      # rubocop: enable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's groups

      def any_group_with_ai_available?
        Rails.cache.fetch(
          ['users', id, GROUP_WITH_AI_ENABLED_CACHE_KEY],
          expires_in: GROUP_WITH_AI_ENABLED_CACHE_PERIOD
        ) do
          member_namespaces.namespace_settings_with_ai_features_enabled.with_ai_supported_plan.any?
        end
      end

      def any_group_with_ga_ai_available?
        Rails.cache.fetch(
          ['users', id, GROUP_WITH_GA_AI_ENABLED_CACHE_KEY],
          expires_in: GROUP_WITH_AI_ENABLED_CACHE_PERIOD
        ) do
          member_namespaces.with_ai_supported_plan.any?
        end
      end

      def ai_chat_enabled_namespace_ids
        Rails.cache.fetch(['users', id, GROUP_IDS_WITH_AI_CHAT_ENABLED_CACHE_KEY],
          expires_in: GROUP_IDS_WITH_AI_CHAT_ENABLED_CACHE_PERIOD) do
          groups = member_namespaces.with_ai_supported_plan(:ai_chat)
          groups.pluck(Arel.sql('DISTINCT traversal_ids[1]')) # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's groups
        end
      end

      def allowed_to_use?(...)
        allowed_to_use(...).allowed?
      end

      def allowed_by_namespace_ids(...)
        allowed_to_use(...).namespace_ids
      end

      def allowed_to_use(ai_feature, service_name: nil, licensed_feature: :ai_features)
        feature_data = Gitlab::Llm::Utils::AiFeaturesCatalogue.search_by_name(ai_feature)
        return Response.new(allowed?: false, namespace_ids: []) unless feature_data

        service = CloudConnector::AvailableServices.find_by_name(service_name || ai_feature)
        return Response.new(allowed?: false, namespace_ids: []) if service.name == :missing_service

        # If the user has any relevant add-on purchase, they always have access to this service
        purchases = service.add_on_purchases.assigned_to_user(self)

        if purchases.any?
          return Response.new(allowed?: true, namespace_ids: purchases.uniq_namespace_ids, enablement_type: 'add_on')
        end

        # If the user doesn't have add-on purchases and the service isn't free, they don't have access
        return Response.new(allowed?: false, namespace_ids: []) unless service.free_access?

        if Gitlab::Saas.feature_available?(:duo_chat_on_saas)
          seats = namespaces_allowed_in_com(feature_data[:maturity])
          if seats.any?
            Response.new(allowed?: true, namespace_ids: seats, enablement_type: 'tier')
          else
            Response.new(allowed?: false, namespace_ids: [])
          end
        else
          Response.new(allowed?: licensed_to_use_in_sm?(licensed_feature), namespace_ids: [])
        end
      end

      private

      def namespaces_allowed_in_com(maturity)
        namespaces = member_namespaces.with_ai_supported_plan
        namespaces = namespaces.namespace_settings_with_ai_features_enabled if maturity != :ga
        namespaces.ids
      end

      def licensed_to_use_in_sm?(licensed_feature)
        License.feature_available?(licensed_feature)
      end
    end

    class_methods do
      def clear_group_with_ai_available_cache(ids)
        cache_keys_ai_features = Array.wrap(ids).map { |id| ["users", id, GROUP_WITH_AI_ENABLED_CACHE_KEY] }
        cache_keys_ga_ai_features = Array.wrap(ids).map { |id| ["users", id, GROUP_WITH_GA_AI_ENABLED_CACHE_KEY] }
        cache_keys_ai_chat_group_ids = Array.wrap(ids).map do |id|
          ["users", id, GROUP_IDS_WITH_AI_CHAT_ENABLED_CACHE_KEY]
        end

        cache_keys = cache_keys_ai_features + cache_keys_ai_chat_group_ids + cache_keys_ga_ai_features
        ::Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
          Rails.cache.delete_multi(cache_keys)
        end
      end

      def duo_pro_cache_key_formatted(user_id)
        format(DUO_PRO_ADD_ON_CACHE_KEY, user_id: user_id)
      end
    end
  end
end
