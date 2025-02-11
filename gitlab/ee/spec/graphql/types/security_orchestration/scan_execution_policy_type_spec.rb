# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ScanExecutionPolicy'], feature_category: :security_policy_management do
  let(:fields) { %i[description edit_path enabled name updated_at yaml policy_scope source deprecated_properties] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
