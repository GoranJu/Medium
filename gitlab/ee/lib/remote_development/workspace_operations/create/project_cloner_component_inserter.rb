# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class ProjectClonerComponentInserter
        include CreateConstants
        include Files

        PROJECT_CLONER_COMPONENT_NAME = "gl-project-cloner"
        PROJECT_CLONING_SUCCESSFUL_FILENAME = ".gl_project_cloning_successful"

        # @param [Hash] context
        # @return [Hash]
        def self.insert(context)
          context => {
            processed_devfile: Hash => processed_devfile,
            volume_mounts: Hash => volume_mounts,
            params: Hash => params,
            settings: Hash => settings
          }
          volume_mounts => { data_volume: Hash => data_volume }
          data_volume => { path: String => volume_path }
          params => {
            project: project,
            project_ref: String => project_ref,
          }
          settings => {
            project_cloner_image: String => image,
          }
          project_cloning_successful_file = "#{volume_path}/#{PROJECT_CLONING_SUCCESSFUL_FILENAME}"

          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/408448
          #       replace the alpine/git docker image with one that is published by gitlab for security / reliability
          #       reasons
          clone_dir = "#{volume_path}/#{project.path}"
          project_url = project.http_url_to_repo

          # The project should be cloned only if one is not cloned successfully already.
          # This is required to avoid resetting user's modifications to the files.
          # This is achieved by checking for the existence of a file before cloning.
          # If the file does not exist, clone the project.
          # To accommodate for scenarios where the project cloning failed midway in the previous attempt,
          # remove the directory before cloning.
          # Once cloning is successful, create the file which is used in the check above.
          # This will ensure the project is not cloned again on restarts.
          container_args = format(PROJECTS_CLONER_COMPONENT_INSERTER_CONTAINER_ARGS,
            project_cloning_successful_file: Shellwords.shellescape(project_cloning_successful_file),
            clone_dir: Shellwords.shellescape(clone_dir),
            project_ref: Shellwords.shellescape(project_ref),
            project_url: Shellwords.shellescape(project_url)
          )

          # TODO: https://gitlab.com/groups/gitlab-org/-/epics/10461
          #       implement better error handling to allow cloner to be able to deal with different categories of errors
          # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/408451
          cloner_component = {
            name: PROJECT_CLONER_COMPONENT_NAME,
            container: {
              image: image,
              args: [container_args],
              # command has been overridden here as the default command in the alpine/git
              # container invokes git directly
              command: %w[/bin/sh -c],
              memoryLimit: "512Mi",
              memoryRequest: "256Mi",
              cpuLimit: "500m",
              cpuRequest: "100m"
            }
          }

          processed_devfile.fetch(:components) << cloner_component

          # create a command that will invoke the cloner
          cloner_command = {
            id: "#{PROJECT_CLONER_COMPONENT_NAME}-command",
            apply: {
              component: cloner_component[:name]
            }
          }
          processed_devfile.fetch(:commands) << cloner_command

          # configure the workspace to run the cloner command upon workspace start
          processed_devfile.fetch(:events)[:preStart] << cloner_command[:id]

          context
        end
      end
    end
  end
end
