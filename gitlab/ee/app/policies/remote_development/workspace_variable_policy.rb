# frozen_string_literal: true

module RemoteDevelopment
  class WorkspaceVariablePolicy < BasePolicy
    condition(:can_read_workspace) { can?(:read_workspace, @subject.workspace) }

    rule { can_read_workspace }.enable :read_workspace_variable
  end
end
