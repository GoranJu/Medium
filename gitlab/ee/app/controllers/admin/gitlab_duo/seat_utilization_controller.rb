# frozen_string_literal: true

# EE:Self Managed
module Admin
  module GitlabDuo
    class SeatUtilizationController < Admin::ApplicationController
      include ::GitlabSubscriptions::CodeSuggestionsHelper

      respond_to :html

      feature_category :seat_cost_management
      urgency :low

      before_action :ensure_feature_available!

      before_action do
        push_frontend_feature_flag(:enable_add_on_users_filtering)
        push_frontend_feature_flag(:enable_add_on_users_pagesize_selection)
      end

      def index
        @subscription_name = License.current.subscription_name
        @subscription_start_date = License.current.starts_at
        @subscription_end_date = License.current.expires_at
      end

      private

      def ensure_feature_available!
        render_404 unless !gitlab_com_subscription? && License.current&.paid?
      end
    end
  end
end
