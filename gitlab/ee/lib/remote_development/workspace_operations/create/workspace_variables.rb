# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class WorkspaceVariables
        include CreateConstants
        include Files

        # @param [String] name
        # @param [String] dns_zone
        # @param [String] personal_access_token_value
        # @param [String] user_name
        # @param [String] user_email
        # @param [Integer] workspace_id
        # @param [Hash] vscode_extensions_gallery
        # @param [Array<Hash>] variables
        # @return [Array<Hash>]
        def self.variables(
          name:, dns_zone:, personal_access_token_value:, user_name:, user_email:, workspace_id:,
          vscode_extensions_gallery:, variables:
        )
          vscode_extensions_gallery => {
            service_url: String => vscode_extensions_gallery_service_url,
            item_url: String => vscode_extensions_gallery_item_url,
            resource_url_template: String => vscode_extensions_gallery_resource_url_template,
          }

          internal_variables = [
            {
              key: File.basename(TOKEN_FILE),
              value: personal_access_token_value,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:file],
              workspace_id: workspace_id
            },
            {
              key: File.basename(GIT_CREDENTIAL_STORE_SCRIPT_FILE),
              value: WORKSPACE_VARIABLES_GIT_CREDENTIAL_STORE_SCRIPT,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:file],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_COUNT',
              value: '3',
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_KEY_0',
              value: "credential.helper",
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_VALUE_0',
              value: GIT_CREDENTIAL_STORE_SCRIPT_FILE,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_KEY_1',
              value: "user.name",
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_VALUE_1',
              value: user_name,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_KEY_2',
              value: "user.email",
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_VALUE_2',
              value: user_email,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_GIT_CREDENTIAL_STORE_SCRIPT_FILE',
              value: GIT_CREDENTIAL_STORE_SCRIPT_FILE,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_TOKEN_FILE_PATH',
              value: TOKEN_FILE,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_WORKSPACE_DOMAIN_TEMPLATE',
              value: "${PORT}-#{name}.#{dns_zone}",
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_EDITOR_EXTENSIONS_GALLERY_SERVICE_URL',
              value: vscode_extensions_gallery_service_url,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_EDITOR_EXTENSIONS_GALLERY_ITEM_URL',
              value: vscode_extensions_gallery_item_url,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_EDITOR_EXTENSIONS_GALLERY_RESOURCE_URL_TEMPLATE',
              value: vscode_extensions_gallery_resource_url_template,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            # variables with prefix `GITLAB_WORKFLOW_` are used for configured GitLab Workflow extension for VS Code
            {
              key: 'GITLAB_WORKFLOW_INSTANCE_URL',
              value: Gitlab::Routing.url_helpers.root_url,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GITLAB_WORKFLOW_TOKEN_FILE',
              value: TOKEN_FILE,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            }
          ]

          user_provided_variables = variables.map do |variable|
            {
              key: variable.fetch(:key),
              value: variable.fetch(:value),
              variable_type: variable.fetch(:type),
              user_provided: true,
              workspace_id: workspace_id
            }
          end

          internal_variables + user_provided_variables
        end
      end
    end
  end
end
