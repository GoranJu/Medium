# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::ComplianceManagement::ComplianceRequirementsControlInputType, feature_category: :compliance_management do
  it { expect(described_class.graphql_name).to eq('ComplianceRequirementsControlInput') }

  it { expect(described_class.arguments.keys).to match_array(%w[name expression]) }
end
