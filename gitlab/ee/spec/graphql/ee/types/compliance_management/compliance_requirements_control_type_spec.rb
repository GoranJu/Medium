# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceRequirementsControl'], feature_category: :compliance_management do
  subject { described_class }

  fields = %w[
    id
    name
    expression
    control_type
  ]

  it 'has the correct fields' do
    is_expected.to have_graphql_fields(fields)
  end
end
