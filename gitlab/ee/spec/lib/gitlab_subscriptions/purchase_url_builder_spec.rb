# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::PurchaseUrlBuilder, feature_category: :subscription_management do
  describe '#build' do
    let(:subscription_portal_url) { Gitlab::Routing.url_helpers.subscription_portal_url }

    let_it_be(:namespace) { create(:group) }

    subject(:builder) { described_class.new(plan_id: 'plan-id', namespace: namespace) }

    it 'generates the customers dot flow URL' do
      expect(builder.build)
        .to eq "#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{namespace.id}&plan_id=plan-id"
    end

    context 'when supplied additional parameters' do
      it 'includes the params in the URL' do
        expected_url = "#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{namespace.id}&" \
          "plan_id=plan-id&source=source"

        expect(builder.build(source: 'source')).to eq expected_url
      end
    end

    context 'when we do not pass the namespace' do
      let(:namespace) { nil }

      it 'generates the new subscriptions group path' do
        expect(builder.build).to eq "/-/subscriptions/groups/new?plan_id=plan-id"
      end
    end
  end
end
