# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::WidgetDefinitions::WeightType, feature_category: :team_planning do
  it 'exposes the expected fields' do
    expected_fields = %i[type editable roll_up]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetDefinitionWeight') }
end
