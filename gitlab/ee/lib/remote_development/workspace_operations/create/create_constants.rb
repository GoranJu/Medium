# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      # NOTE: Constants are scoped to the use-case namespace in which they are used in production
      #       code (but they may still be referenced by specs or fixtures or factories).
      #       For example, this RemoteDevelopment::WorkspaceOperations::Create::CreateConstants
      #       file contains constants which are only used by classes within that namespace.
      #
      #       See documentation at ../../README.md#constant-declarations for more information.
      module CreateConstants
        include WorkspaceOperationsConstants

        # Please keep alphabetized
        GIT_CREDENTIAL_STORE_SCRIPT_FILE = "#{VARIABLES_FILE_DIR}/gl_git_credential_store.sh".freeze
        MAIN_COMPONENT_INDICATOR_ATTRIBUTE = "gl/inject-editor"
        NAMESPACE_PREFIX = "gl-rd-ns"
        TOKEN_FILE = "#{VARIABLES_FILE_DIR}/gl_token".freeze
        TOOLS_DIR_NAME = ".gl-tools"
        TOOLS_DIR_ENV_VAR = "GL_TOOLS_DIR"
        TOOLS_INJECTOR_COMPONENT_NAME = "gl-tools-injector"
        WORKSPACE_DATA_VOLUME_NAME = "gl-workspace-data"
        WORKSPACE_DATA_VOLUME_PATH = "/projects"
        WORKSPACE_EDITOR_PORT = 60001
      end
    end
  end
end
