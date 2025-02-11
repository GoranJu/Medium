# frozen_string_literal: true

FactoryBot.define do
  factory :project_control_compliance_status,
    class: 'ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus' do
    compliance_requirement { association(:compliance_requirement) }
    namespace { compliance_requirement.namespace }
    project { association(:project, namespace: compliance_requirement.namespace) }
    compliance_requirements_control do
      association(:compliance_requirements_control, compliance_requirement: compliance_requirement)
    end
    status { 'pass' }
  end
end
