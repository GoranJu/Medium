# frozen_string_literal: true

module Search
  module Zoekt
    class CircuitBreaker
      attr_reader :nodes, :cache_timeout

      def initialize(*nodes, cache_timeout: 2.seconds)
        @nodes = nodes
        @cache_timeout = cache_timeout
      end

      def operational?
        !broken?
      end

      def broken?
        return false if Feature.disabled?(:zoekt_node_backoffs, type: :ops)

        Rails.cache.fetch(circuit_breaker_cache_key, expires_in: cache_timeout) do
          operational_nodes.none?
        end
      end

      def operational_nodes
        registry.fetch(:operational_nodes)
      end

      def backoffs
        registry.fetch(:backoffs)
      end

      def registry
        @registry ||= { operational_nodes: [], backoffs: [] }.with_indifferent_access.tap do |hsh|
          nodes.each do |node|
            if node.backoff.enabled?
              hsh[:backoffs] << node
            else
              hsh[:operational_nodes] << node
            end
          end
        end
      end

      def reset!
        Rails.cache.delete(circuit_breaker_cache_key)
        @registry = nil
      end

      private

      def circuit_breaker_cache_key
        [self.class.name, nodes.map(&:id).join("-")]
      end
    end
  end
end
