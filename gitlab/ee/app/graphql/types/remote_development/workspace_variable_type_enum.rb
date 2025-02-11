# frozen_string_literal: true

module Types
  module RemoteDevelopment
    class WorkspaceVariableTypeEnum < BaseEnum
      graphql_name 'WorkspaceVariableType'
      description 'Enum for the type of the variable injected in a workspace.'

      ::RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES.slice(:environment).each do |name, value|
        value name.to_s.upcase, value: value, description: "#{name.to_s.capitalize} type."
      end

      def self.environment
        enum[:environment]
      end
    end
  end
end
