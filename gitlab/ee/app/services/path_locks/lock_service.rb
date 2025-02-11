# frozen_string_literal: true

module PathLocks
  class LockService < BaseService
    AccessDenied = Class.new(StandardError)

    include PathLocksHelper

    def execute(path)
      raise AccessDenied, 'You have no permissions' unless can?(current_user, :push_code, project)

      project.path_locks.create(path: path, user: current_user).tap do |path_lock|
        project.refresh_path_locks_changed_epoch if path_lock.persisted?
      end
    end
  end
end
