# frozen_string_literal: true

module WorkItems
  module DataSync
    module Widgets
      class CustomFields < Base
        def after_save_commit
          # copy custom field values if field exists in target namespace
        end
      end
    end
  end
end
