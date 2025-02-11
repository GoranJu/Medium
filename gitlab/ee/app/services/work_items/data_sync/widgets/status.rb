# frozen_string_literal: true

module WorkItems
  module DataSync
    module Widgets
      class Status < Base
        def after_save_commit
          # copy Status
        end

        def post_move_cleanup
          # do it
        end
      end
    end
  end
end
