# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceFramework'] do
  subject { described_class }

  fields = %w[
    id
    name
    description
    color
    default
    pipeline_configuration_full_path
    projects
    scan_result_policies
    scan_execution_policies
    pipeline_execution_policies
    compliance_requirements
    vulnerability_management_policies
  ]

  it 'has the correct fields' do
    is_expected.to have_graphql_fields(fields)
  end
end
