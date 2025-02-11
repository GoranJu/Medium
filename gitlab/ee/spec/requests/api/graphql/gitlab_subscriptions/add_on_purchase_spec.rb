# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.addOnPurchase', feature_category: :seat_cost_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on) }

  let(:fields) { 'id purchasedQuantity assignedQuantity name' }
  let(:add_on_type) { :CODE_SUGGESTIONS }

  let(:query) do
    graphql_query_for(
      :addOnPurchase, { add_on_type: add_on_type },
      fields
    )
  end

  let(:expected_response) do
    {
      'id' => "gid://gitlab/GitlabSubscriptions::AddOnPurchase/#{add_on_purchase.id}",
      'purchasedQuantity' => 1,
      'assignedQuantity' => 0,
      'name' => 'CODE_SUGGESTIONS'
    }
  end

  shared_examples 'empty response' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data['addOnPurchase']).to eq(nil)
    end
  end

  shared_examples 'successful response' do
    it 'returns expected response' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data['addOnPurchase']).to eq(expected_response)
    end
  end

  context 'when namespace_id is not provided as argument' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace_id: nil) }

    it_behaves_like 'successful response'

    context 'when seats are assigned' do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase)

        expected_response['assignedQuantity'] = 1
      end

      it_behaves_like 'successful response'
    end

    context 'when no active add_on_purchase is present' do
      before do
        add_on_purchase.update!(expires_on: 1.day.ago)
      end

      it_behaves_like 'empty response'
    end

    context 'when started_at is future dated' do
      before do
        add_on_purchase.update!(started_at: 1.day.from_now)
      end

      it_behaves_like 'empty response'
    end

    context 'when expires_on date is today' do
      before do
        add_on_purchase.update!(expires_on: Date.current)
      end

      it_behaves_like 'empty response'
    end

    context 'when current_user is not eligible to admin add_on_purchase' do
      let(:current_user) { create(:user) }
      let(:group) { create(:group) }

      before do
        group.add_owner(current_user)
      end

      it_behaves_like 'empty response'
    end
  end

  context 'when namespace_id is provided as an argument' do
    let_it_be(:group) { create(:group) }
    let_it_be(:other_group) { create(:group) }
    let_it_be(:owner) { create(:user) }
    let_it_be(:other_owner) { create(:user) }
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace_id: group.id) }

    let(:query) do
      graphql_query_for(
        :addOnPurchase, { add_on_type: add_on_type, namespace_id: global_id_of(group) },
        fields
      )
    end

    before_all do
      group.add_owner(owner)
      other_group.add_owner(other_owner)
    end

    it_behaves_like 'successful response'

    context 'when current_user is the owner of associated namespace' do
      let(:current_user) { owner }

      it_behaves_like 'successful response'
    end

    context 'when current_user is not the owner of associated namespace' do
      let(:current_user) { other_owner }

      it_behaves_like 'empty response'
    end
  end
end
