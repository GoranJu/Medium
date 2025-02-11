# frozen_string_literal: true

module Gitlab
  module Search
    class Client
      include ::Elastic::Latest::Routing

      DELEGATED_METHODS = %i[cat count delete_by_query index indices reindex update_by_query search].freeze

      delegate(*DELEGATED_METHODS, to: :adapter)

      def self.execute_search(...)
        new(adapter: search_adapter).execute_search(...)
      end

      def self.search_adapter
        Gitlab::Elastic::Helper.new(operation: :search).client
      end

      def initialize(adapter: nil)
        @adapter = adapter || default_adapter
      end

      def execute_search(query:, options:)
        es_query = routing_options(options).merge(
          timeout: options[:count_only] ? '1s' : '30s',
          index: options[:index_name] || options[:klass].index_name,
          body: query
        )

        yield search(es_query)
      end

      private

      attr_reader :adapter

      def default_adapter
        # Note: in the future, the default adapter should be changed to whatever
        # adapter is compatible with the version of search engine that is being used
        # in GitLab's application settings.
        ::Gitlab::Elastic::Helper.default.client
      end
    end
  end
end
