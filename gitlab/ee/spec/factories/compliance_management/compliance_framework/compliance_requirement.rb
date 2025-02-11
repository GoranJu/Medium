# frozen_string_literal: true

FactoryBot.define do
  factory :compliance_requirement, class: 'ComplianceManagement::ComplianceFramework::ComplianceRequirement' do
    association :framework, factory: :compliance_framework
    namespace_id { framework.namespace_id }
    name { 'Merge Request Controls' }
    description { 'Requirement for adding checks related to merge request controls' }
    requirement_type { 'internal' }
    control_expression do
      {
        operator: "=",
        field: "minimum_approvals_required",
        value: 2
      }.to_json
    end
  end
end
