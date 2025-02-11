# frozen_string_literal: true

module Mutations
  module RemoteDevelopment
    module WorkspaceOperations
      class Create < BaseMutation
        graphql_name 'WorkspaceCreate'

        include Gitlab::Utils::UsageData

        authorize :create_workspace

        field :workspace,
          Types::RemoteDevelopment::WorkspaceType,
          null: true,
          description: 'Created workspace.'

        argument :cluster_agent_id,
          ::Types::GlobalIDType[::Clusters::Agent],
          required: true,
          description: 'GlobalID of the cluster agent the created workspace will be associated with.'

        # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409772 - Make this a type:enum
        argument :desired_state,
          GraphQL::Types::String,
          required: true,
          description: 'Desired state of the created workspace.'

        # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/498322 - Remove in 18.0
        argument :editor,
          GraphQL::Types::String,
          required: false,
          description: 'Editor to inject into the created workspace. Must match a configured template.',
          deprecated: { reason: 'Argument is not used', milestone: '17.5' }

        argument :max_hours_before_termination,
          GraphQL::Types::Int,
          required: false,
          description: 'Maximum hours the workspace can exist before it is automatically terminated.',
          deprecated: { reason: 'Field is not used', milestone: '17.9' }

        argument :project_id,
          ::Types::GlobalIDType[::Project],
          required: true,
          description: 'ID of the project that will provide the Devfile for the created workspace.'

        # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/510078 - Remove in 19.0
        argument :devfile_ref,
          GraphQL::Types::String,
          required: false,
          description: 'Project repo git ref containing the devfile used to configure the workspace.',
          deprecated: { reason: 'Argument is renamed to project_ref', milestone: '17.8' }

        argument :project_ref,
          GraphQL::Types::String,
          required: false,
          description: 'Project repo git ref.'

        argument :devfile_path,
          GraphQL::Types::String,
          required: false,
          default_value: nil,
          description: 'Project path containing the devfile used to configure the workspace. ' \
            'If not provided, the GitLab default devfile is used.'

        argument :variables, [::Types::RemoteDevelopment::WorkspaceVariableInput],
          required: false,
          default_value: [],
          replace_null_with_default: true,
          description: 'Variables to inject into the workspace.'

        # @param [Hash] args
        def resolve(args)
          unless License.feature_available?(:remote_development)
            raise_resource_not_available_error!("'remote_development' licensed feature is not available")
          end

          project_id = args.delete(:project_id)
          project = authorized_find!(id: project_id)

          cluster_agent_id = args.delete(:cluster_agent_id)

          # Ensure that at least one of 'devfile_ref' or 'project_ref' is provided,
          # raising an error if neither is present.
          unless args[:devfile_ref] || args[:project_ref]
            raise ::Gitlab::Graphql::Errors::ArgumentError,
              "Either 'project_ref' or deprecated 'devfile_ref' must be provided."
          end

          # Remove 'devfile_ref' from the arguments.
          # If 'project_ref' is not specified, assign 'devfile_ref' to 'project_ref' for backward compatibility.
          devfile_ref = args.delete(:devfile_ref)
          args[:project_ref] = devfile_ref if args[:project_ref].nil?

          # NOTE: What the following line actually does - the agent is delegating to the project to check that the user
          # has the :create_workspace ability on the _agent's_ project, which will be true if the user is a developer
          # on the agent's project.
          agent = authorized_find!(id: cluster_agent_id)
          relevant_mappings =
            ::RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping
              .for_namespaces(project.project_namespace.traversal_ids)
              .for_agents([agent.id])

          unless relevant_mappings.present?
            raise ::Gitlab::Graphql::Errors::ArgumentError,
              "The provided agent provided must be mapped to an ancestor namespace of the workspace's project."
          end

          valid_relevant_mappings =
            ::RemoteDevelopment::NamespaceClusterAgentMappingOperations::Validations
              .filter_valid_namespace_cluster_agent_mappings(namespace_cluster_agent_mappings: relevant_mappings.to_a)

          unless valid_relevant_mappings.present?
            raise ::Gitlab::Graphql::Errors::ArgumentError,
              "#{relevant_mappings.size} mapping(s) exist between the provided agent and the ancestor namespaces " \
                "of the workspaces's project, but the agent does not reside within the hierarchy of any of the " \
                "mapped ancestor namespaces."
          end

          # noinspection RubyNilAnalysis - This is because the superclass #current_user uses #[], which can return nil
          track_usage_event(:users_creating_workspaces, current_user.id)

          variables = args.fetch(:variables, []).map(&:to_h)
          params = args.merge(
            agent: agent,
            user: current_user,
            project: project,
            variables: variables
          )

          WebIde::Settings.get(
            [:vscode_extensions_gallery_metadata, :vscode_extensions_gallery],
            user: current_user,
            vscode_extensions_marketplace_feature_flag_enabled: true
          ) =>
            {
              vscode_extensions_gallery_metadata: Hash => vscode_extensions_gallery_metadata,
              vscode_extensions_gallery: Hash => vscode_extensions_gallery
            }

          domain_main_class_args = {
            user: current_user,
            params: params,
            vscode_extensions_gallery_metadata: vscode_extensions_gallery_metadata,
            vscode_extensions_gallery: vscode_extensions_gallery
          }

          response = ::RemoteDevelopment::CommonService.execute(
            domain_main_class: ::RemoteDevelopment::WorkspaceOperations::Create::Main,
            domain_main_class_args: domain_main_class_args,
            auth_ability: :create_workspace,
            auth_subject: project,
            current_user: current_user
          )

          response_object = response.success? ? response.payload[:workspace] : nil

          {
            workspace: response_object,
            errors: response.errors
          }
        end
      end
    end
  end
end
