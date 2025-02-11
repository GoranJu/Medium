# frozen_string_literal: true

module Groups
  module Settings
    class WorkItemsController < Groups::ApplicationController
      layout 'group_settings'

      before_action :check_feature_availability
      before_action :authorize_admin_work_item_settings

      feature_category :team_planning
      urgency :low

      def show; end

      private

      def check_feature_availability
        render_404 unless group.licensed_feature_available?(:custom_fields) &&
          Feature.enabled?('custom_fields_feature', group)
      end

      def authorize_admin_work_item_settings
        render_404 unless can?(current_user, :admin_custom_field, group)
      end
    end
  end
end
