# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Fetching a single custom field', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let_it_be(:text_field) { create(:custom_field, namespace: group, field_type: 'text') }

  let(:query) do
    <<~QUERY
    query($id: IssuablesCustomFieldID!) {
      group(fullPath: "#{group.full_path}") {
        customField(id: $id) {
          id
          name
        }
      }
    }
    QUERY
  end

  before do
    stub_licensed_features(custom_fields: true)
  end

  it 'returns custom field with the given ID' do
    post_graphql(query, current_user: guest, variables: { id: text_field.to_global_id.to_s })

    expect(response).to have_gitlab_http_status(:ok)

    expect(graphql_data_at(:group, :customField)).to match(
      a_hash_including(
        'id' => text_field.to_global_id.to_s,
        'name' => text_field.name
      )
    )
  end

  context 'when feature is not available' do
    before do
      stub_licensed_features(custom_fields: false)
    end

    it 'returns an empty result' do
      post_graphql(query, current_user: guest, variables: { id: text_field.to_global_id.to_s })

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:group, :customField)).to be_blank
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(custom_fields_feature: false)
    end

    it 'returns an empty result' do
      post_graphql(query, current_user: guest, variables: { id: text_field.to_global_id.to_s })

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:group, :customField)).to be_blank
    end
  end
end
