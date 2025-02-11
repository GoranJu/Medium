# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomizablePermission'], feature_category: :permissions do
  include GraphqlHelpers

  it { expect(described_class.graphql_name).to eq('CustomizablePermission') }

  it 'has the expected fields' do
    expected_fields = %i[
      available_for
      description
      name
      requirements
      value
      available_from_access_level
      enabled_for_group_access_levels
      enabled_for_project_access_levels
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
