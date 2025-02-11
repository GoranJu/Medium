# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_workflow, class: 'Ai::DuoWorkflows::Workflow' do
    project { association(:project) }
    user { association(:user, developer_of: project) }
    goal { "Fix pipeline" }
    agent_privileges { [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES] }
    workflow_definition { "software_development" }
  end
end
