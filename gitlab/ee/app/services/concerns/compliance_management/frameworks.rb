# frozen_string_literal: true

module ComplianceManagement
  module Frameworks
    def compliance_pipeline_configuration_available?
      return true if params[:pipeline_configuration_full_path].blank?

      can?(current_user, :admin_compliance_pipeline_configuration, framework)
    end
  end
end
