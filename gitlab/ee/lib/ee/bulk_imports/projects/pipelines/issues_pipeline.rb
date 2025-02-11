# frozen_string_literal: true

module EE
  module BulkImports
    module Projects
      module Pipelines
        module IssuesPipeline
          include ::BulkImports::EpicObjectCreator

          def load(context, data)
            issue, _original_users_map = data

            return unless issue

            super

            # In some instances the issue would not be valid, but would be persisted, if some associations are invalid,
            # e.g. Designs missing the author
            #
            # We still want to make sure we create the work_item_parent_links relationship if one should exist if
            # the issue was persisted.
            handle_epic_issue(issue)
          end
        end
      end
    end
  end
end
