# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectSetting'], feature_category: :code_suggestions do
  it 'includes project setting fields' do
    expected_fields = %w[
      duo_features_enabled
      project
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  it { expect(described_class.graphql_name).to eq('ProjectSetting') }
end
