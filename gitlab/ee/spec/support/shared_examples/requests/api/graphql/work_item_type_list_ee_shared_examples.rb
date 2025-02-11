# frozen_string_literal: true

RSpec.shared_examples 'graphql work item type list request spec EE' do
  include GraphqlHelpers

  let(:parent_key) { parent.to_ability_name.to_sym }
  let(:licensed_features) { WorkItems::Type::LICENSED_WIDGETS.keys }
  let(:disabled_features) { [] }
  let(:work_item_type_fields) { 'name widgetDefinitions { type }' }
  let(:returned_widgets) do
    graphql_data_at(parent_key.to_s, 'workItemTypes', 'nodes').flat_map do |type|
      type['widgetDefinitions'].pluck('type')
    end.uniq
  end

  let(:query) do
    graphql_query_for(
      parent_key.to_s,
      { 'fullPath' => parent.full_path },
      query_nodes('WorkItemTypes', work_item_type_fields)
    )
  end

  describe 'licensed widgets' do
    before do
      stub_licensed_features(**feature_hash)
      post_graphql(query, current_user: current_user)
    end

    where(feature_widget: WorkItems::Type::LICENSED_WIDGETS.transform_values { |v| Array(v) }.to_a)

    with_them do
      let(:feature) { feature_widget.first }
      let(:widgets) { feature_widget.last }

      context 'when feature is available' do
        it 'returns the associated licensesd widget' do
          widgets.each do |widget|
            expect(returned_widgets).to include(widget_to_enum_string(widget))
          end
        end
      end

      context 'when feature is not available' do
        let(:disabled_features) { [feature] }

        it 'does not return the unlincensed widgets' do
          post_graphql(query, current_user: developer)

          widgets.each do |widget|
            expect(returned_widgets).not_to include(widget_to_enum_string(widget))
          end
        end
      end
    end
  end

  def widget_to_enum_string(widget)
    widget.type.to_s.upcase
  end

  def feature_hash
    available_features = licensed_features - disabled_features

    available_features.index_with { |_| true }.merge(disabled_features.index_with { |_| false })
  end
end
