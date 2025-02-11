# frozen_string_literal: true

module API
  module Entities
    module Ai
      module DuoWorkflows
        class Workflow < Grape::Entity
          expose :id
          expose :project_id
          expose :agent_privileges
          expose :agent_privileges_names
          expose :workflow_definition
          expose :status_name, as: :status

          def agent_privileges_names
            object.agent_privileges.map do |privilege|
              ::Ai::DuoWorkflows::Workflow::AgentPrivileges::ALL_PRIVILEGES[privilege][:name]
            end
          end
        end
      end
    end
  end
end
