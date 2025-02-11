# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowPolicy < BasePolicy
      condition(:can_use_duo_workflows_in_project) do
        can?(:duo_workflow, @subject.project)
      end

      condition(:is_workflow_owner) do
        @subject.user == @user
      end

      rule { can_use_duo_workflows_in_project & is_workflow_owner }.policy do
        enable :read_duo_workflow
        enable :update_duo_workflow
      end
    end
  end
end
