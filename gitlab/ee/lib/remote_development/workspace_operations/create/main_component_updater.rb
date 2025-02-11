# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class MainComponentUpdater
        include CreateConstants
        include Files

        WORKSPACE_SSH_PORT = 60022

        # @param [Hash] context
        # @return [Hash]
        def self.update(context)
          context => {
            processed_devfile: Hash => processed_devfile,
            tools_dir: String => tools_dir,
            vscode_extensions_gallery_metadata: Hash => vscode_extensions_gallery_metadata
          }

          # NOTE: We will always have exactly one main_component found, because we have already
          #       validated this in post_flatten_devfile_validator.rb
          main_component =
            processed_devfile
              .fetch(:components)
              .find { |component| component.dig(:attributes, MAIN_COMPONENT_INDICATOR_ATTRIBUTE.to_sym) }

          container = main_component.fetch(:container)

          update_env_vars(
            container: container,
            tools_dir: tools_dir,
            editor_port: WORKSPACE_EDITOR_PORT,
            ssh_port: WORKSPACE_SSH_PORT,
            enable_marketplace: vscode_extensions_gallery_metadata.fetch(:enabled)
          )

          update_endpoints(
            container: container,
            editor_port: WORKSPACE_EDITOR_PORT,
            ssh_port: WORKSPACE_SSH_PORT
          )

          override_command_and_args(
            container: container
          )

          context
        end

        # @param [Hash] container
        # @param [String] tools_dir
        # @param [Integer] editor_port
        # @param [Integer] ssh_port
        # @param [Boolean] enable_marketplace
        # @return [void]
        def self.update_env_vars(container:, tools_dir:, editor_port:, ssh_port:, enable_marketplace:)
          (container[:env] ||= []).append(
            {
              # NOTE: Only "TOOLS_DIR" env var is extracted to a constant, because it is the only one referenced
              #       in multiple different classes.
              name: TOOLS_DIR_ENV_VAR,
              value: tools_dir
            },
            {
              name: "GL_EDITOR_LOG_LEVEL",
              value: "info"
            },
            {
              name: "GL_EDITOR_PORT",
              value: editor_port.to_s
            },
            {
              name: "GL_SSH_PORT",
              value: ssh_port.to_s
            },
            {
              name: "GL_EDITOR_ENABLE_MARKETPLACE",
              value: enable_marketplace.to_s
            }
          )

          nil
        end

        # @param [Hash] container
        # @param [Integer] editor_port
        # @param [Integer] ssh_port
        # @return [void]
        def self.update_endpoints(container:, editor_port:, ssh_port:)
          (container[:endpoints] ||= []).append(
            {
              name: "editor-server",
              targetPort: editor_port,
              exposure: "public",
              secure: true,
              protocol: "https"
            },
            {
              name: "ssh-server",
              targetPort: ssh_port,
              exposure: "internal",
              secure: true
            }
          )

          nil
        end

        # @param [Hash] container
        # @return [void]
        def self.override_command_and_args(container:)
          # This overrides the main container's command
          # Open issue to support both starting the editor and running the default command:
          # https://gitlab.com/gitlab-org/gitlab/-/issues/392853
          container_args = MAIN_COMPONENT_UPDATER_CONTAINER_ARGS

          container[:command] = %w[/bin/sh -c]
          container[:args] = [container_args]

          nil
        end

        private_class_method :update_env_vars, :update_endpoints, :override_command_and_args
      end
    end
  end
end
