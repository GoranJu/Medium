# frozen_string_literal: true

module PathLocks
  class UnlockService < BaseService
    AccessDenied = Class.new(StandardError)

    include PathLocksHelper

    def execute(path_lock)
      raise AccessDenied, _('You have no permissions') unless can_unlock?(path_lock)

      path_lock.destroy.tap do |record|
        project.refresh_path_locks_changed_epoch if record.destroyed?
      end
    end
  end
end
