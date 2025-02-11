# frozen_string_literal: true

FactoryBot.define do
  # noinspection RailsParamDefResolve -- RubyMine doesn't recognize a String as a valid type for `class:`
  #     TODO: Open ticket and link on https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/
  factory :workspaces_agent_config, class: 'RemoteDevelopment::WorkspacesAgentConfig' do
    agent factory: :cluster_agent
    enabled { true }
    dns_zone { 'workspaces.localdev.me' }

    after(:build) do |workspaces_agent_config, _evaluator|
      workspaces_agent_config.project_id = workspaces_agent_config.agent.project_id
    end
  end
end
