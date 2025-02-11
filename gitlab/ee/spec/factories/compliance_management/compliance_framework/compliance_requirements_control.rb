# frozen_string_literal: true

FactoryBot.define do
  factory :compliance_requirements_control,
    class: 'ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl' do
    compliance_requirement
    namespace_id { compliance_requirement.namespace_id }
    name { 'minimum_approvals_required_2' }
    control_type { 'internal' }
    expression do
      {
        operator: "=",
        field: "minimum_approvals_required",
        value: 2
      }.to_json
    end

    trait "external" do
      external_url { FFaker::Internet.unique.http_url }
      control_type { 'external' }
      secret_token { 'token' }
    end
  end
end
