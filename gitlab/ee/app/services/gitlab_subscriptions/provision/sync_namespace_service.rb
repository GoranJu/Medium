# frozen_string_literal: true

# Service for syncing namespace provisions from CustomersDot
# @param namespace [Group] the namespace to sync
# @param params [Hash] provision params containing:
#   - event_type [String] must be "sync"
#   - main_plan [Hash] plan parameters
#   - storage [Hash] storage parameters
#   - compute_minutes [Hash] compute minutes parameters
module GitlabSubscriptions
  module Provision
    class SyncNamespaceService
      attr_reader :namespace, :params

      def initialize(namespace:, params:)
        @namespace = namespace
        @params = params
        @errors = []
      end

      def execute
        sync_main_plan
        sync_storage
        sync_compute_minutes
        sync_add_on_purchases

        return ServiceResponse.success if errors.blank?

        ServiceResponse.error(message: errors.flatten.join(', '))
      end

      private

      attr_reader :errors

      def main_plan_params
        params[:main_plan]
      end

      def compute_minutes_params
        params[:compute_minutes]
      end

      def storage_params
        params[:storage]
      end

      def add_on_purchases_params
        params[:add_on_purchases]
      end

      def sync_main_plan
        return if main_plan_params.blank?

        return if namespace.update(gitlab_subscription_attributes: main_plan_params)

        errors << namespace.errors.full_messages
      end

      def sync_storage
        return if storage_params.blank?

        return if namespace.reset.update(storage_params)

        errors << namespace.errors.full_messages
      end

      def sync_compute_minutes
        return if compute_minutes_params.blank?

        result = SyncComputeMinutesService.new(namespace: namespace.reset, params: compute_minutes_params).execute
        return if result.success?

        errors << result.message
      end

      def sync_add_on_purchases
        return if add_on_purchases_params.blank?

        result = ::GitlabSubscriptions::AddOnPurchases::GitlabCom::ProvisionService.new(
          namespace.reset,
          add_on_purchases_params
        ).execute
        return if result.success?

        errors << result.message
      end
    end
  end
end
