# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ProjectControlComplianceStatus < ApplicationRecord
      belongs_to :compliance_requirements_control
      belongs_to :project
      belongs_to :namespace
      belongs_to :compliance_requirement

      enum status: {
        pass: 0,
        fail: 1,
        pending: 2
      }

      validates :project_id, uniqueness: { scope: :compliance_requirements_control_id }
      validates_presence_of :status, :project, :namespace, :compliance_requirement,
        :compliance_requirements_control

      scope :for_project_and_control, ->(project_id, control_id) {
        where(project_id: project_id, compliance_requirements_control_id: control_id)
      }
    end
  end
end
