# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ScanResultPolicy'], feature_category: :security_policy_management do
  let(:fields) do
    %i[description edit_path enabled name updated_at yaml policy_scope source deprecated_properties
      action_approvers all_group_approvers role_approvers user_approvers custom_roles]
  end

  it { expect(described_class).to have_graphql_fields(fields) }
end
