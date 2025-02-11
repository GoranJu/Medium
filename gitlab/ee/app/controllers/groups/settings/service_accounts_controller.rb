# frozen_string_literal: true

module Groups
  module Settings
    class ServiceAccountsController < Groups::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper

      feature_category :user_management

      before_action :ensure_service_accounts_available!
      before_action :ensure_root_group!
      before_action :authorize_admin_service_accounts!

      private

      def ensure_service_accounts_available!
        render_404 unless Feature.enabled?(:service_accounts_crud, group.root_ancestor)
      end

      def authorize_admin_service_accounts!
        render_404 unless can?(current_user, :admin_service_accounts, group)
      end

      def ensure_root_group!
        render_404 unless group.root?
      end
    end
  end
end
