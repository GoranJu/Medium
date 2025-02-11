# frozen_string_literal: true

module EE
  module Banzai
    module Filter
      # HTML filter that appends extra information to issuable links.
      # Runs as a post-process filter as issuable might change while
      # Markdown is in the cache.
      #
      # This filter supports cross-project references.
      module IssuableReferenceExpansionFilter
        extend ::Gitlab::Utils::Override

        private

        override :expand_reference_with_summary
        def expand_reference_with_summary(node, issuable)
          # Attempt to generate the summary using the associated work item for epics if work_item_epics_enabled?, since
          # the assignees and other relevant info is linked to the work item record
          issuable = issuable.work_item if issuable.is_a?(Epic) && work_item_epics_enabled? && issuable.work_item

          super
        end

        def work_item_epics_enabled?
          (project&.group || group)&.work_item_epics_enabled?
        end
      end
    end
  end
end
