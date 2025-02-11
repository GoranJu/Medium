# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::CircuitBreaker, :clean_gitlab_redis_cache, feature_category: :global_search do
  subject(:breaker) { described_class.new(*nodes) }

  let(:nodes) { create_list(:zoekt_node, 2) }

  describe '.operational_nodes' do
    it 'returns nodes that do not have a backoff' do
      backoff = ::Search::Zoekt::NodeBackoff.new(nodes.first)
      backoff.backoff!

      expect(breaker.operational_nodes).to match_array([nodes.last])
    end
  end

  describe '.backoffs' do
    it 'returns list of backoffs' do
      backoff_node = nodes.first
      backoff_node.backoff.backoff!

      expect(breaker.backoffs).to match_array([backoff_node])

      backoff_node.backoff.remove_backoff!
      breaker.reset!
      expect(breaker.backoffs).to be_empty
    end
  end

  describe '.broken?' do
    it 'returns true when there are no operational nodes' do
      allow(breaker).to receive(:operational_nodes).and_return([])
      expect(breaker).to be_broken

      allow(breaker).to receive(:operational_nodes).and_return([:foo])
      expect(breaker).not_to be_broken
    end

    context 'when feature flag zoekt_node_backoffs is disabled' do
      it 'always returns false even if there are no operational nodes' do
        stub_feature_flags(zoekt_node_backoffs: false)

        allow(breaker).to receive(:operational_nodes).and_return([])
        expect(breaker).not_to be_broken
      end
    end
  end

  describe '.operational?' do
    it 'is the opposite of .broken?' do
      allow(breaker).to receive(:broken?).and_return(true)
      expect(breaker).not_to be_operational

      allow(breaker).to receive(:broken?).and_return(false)
      expect(breaker).to be_operational
    end
  end
end
