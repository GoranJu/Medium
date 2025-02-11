# frozen_string_literal: true

module Security
  class VulnerabilitiesController < ::Security::ApplicationController
    layout 'instance_security'
    include GovernUsageTracking

    track_govern_activity 'security_vulnerabilities', :index
    track_internal_event :index, name: 'visit_vulnerability_report', category: name

    before_action do
      push_frontend_feature_flag(:vulnerability_report_owasp_2021, current_user)
      push_frontend_feature_flag(:vulnerability_report_vr_badge, current_user, type: :beta)
      push_frontend_feature_flag(:vulnerability_report_vr_filter, current_user, type: :beta)
      push_frontend_feature_flag(:enhanced_vulnerability_bulk_actions, current_user, type: :wip)

      push_frontend_ability(ability: :resolve_vulnerability_with_ai, resource: vulnerable, user: current_user)
    end

    private

    def tracking_namespace_source
      nil
    end

    def tracking_project_source
      nil
    end
  end
end
