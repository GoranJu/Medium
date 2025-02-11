# frozen_string_literal: true

module Admin
  module ApplicationSettings
    class RolesAndPermissionsController < Admin::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper
      include ::EE::RolesAndPermissions # rubocop: disable Cop/InjectEnterpriseEditionModule -- EE-only concern

      feature_category :user_management

      before_action :authorize_admin_member_roles!, except: [:index, :show]
      before_action :authorize_view_member_roles!, only: [:index, :show]

      private

      def authorize_admin_member_roles!
        render_404 if gitlab_com_subscription? || !can?(current_user, :admin_member_role)
      end

      def authorize_view_member_roles!
        render_404 if gitlab_com_subscription? || !can?(current_user, :view_member_roles)
      end
    end
  end
end
