# frozen_string_literal: true
class Groups::Security::ComplianceDashboardsController < Groups::ApplicationController
  include Groups::SecurityFeaturesHelper
  include ProductAnalyticsTracking

  layout 'group'

  before_action :authorize_compliance_dashboard!

  before_action do
    push_frontend_ability(ability: :admin_compliance_framework, resource: group, user: current_user)
  end

  track_internal_event :show, name: 'g_compliance_dashboard'

  feature_category :compliance_management

  def show; end

  def tracking_namespace_source
    group
  end

  def tracking_project_source
    nil
  end
end
