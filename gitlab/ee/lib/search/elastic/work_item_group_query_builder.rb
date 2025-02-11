# frozen_string_literal: true

module Search
  module Elastic
    class WorkItemGroupQueryBuilder < ::Search::Elastic::WorkItemQueryBuilder
      extend ::Gitlab::Utils::Override

      private

      override :hybrid_work_item_search?
      def hybrid_work_item_search?
        false
      end

      override :extra_options
      def extra_options
        super.merge({
          features: nil,
          group_level_authorization: true,
          group_level_confidentiality: true
        })
      end
    end
  end
end
