# frozen_string_literal: true

FactoryBot.define do
  factory :workspace_variable, class: 'RemoteDevelopment::WorkspaceVariable' do
    workspace

    key { 'my_key' }
    value { 'my_value' }
    user_provided { false }
    variable_type { RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:file] }
  end
end
