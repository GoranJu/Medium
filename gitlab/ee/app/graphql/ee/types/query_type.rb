# frozen_string_literal: true

module EE
  module Types
    module QueryType
      extend ActiveSupport::Concern
      prepended do
        field :add_on_purchase,
          ::Types::GitlabSubscriptions::AddOnPurchaseType,
          null: true,
          description: 'Retrieve the active add-on purchase. ' \
                       'This query can be used in GitLab SaaS and self-managed environments.',
          deprecated: { reason: 'Use [addOnPurchases](#queryaddonpurchases) instead', milestone: '17.4' },
          resolver: ::Resolvers::GitlabSubscriptions::AddOnPurchaseResolver
        field :add_on_purchases,
          [::Types::GitlabSubscriptions::AddOnPurchaseType],
          null: true,
          description: 'Retrieve all active add-on purchases. ' \
                       'This query can be used in GitLab.com and self-managed environments.',
          resolver: ::Resolvers::GitlabSubscriptions::AddOnPurchasesResolver
        field :blob_search, ::Types::Search::Blob::BlobSearchType,
          null: true,
          resolver: ::Resolvers::Search::Blob::BlobSearchResolver,
          experiment: { milestone: '17.2' },
          description: 'Find code visible to the current user'
        field :ci_minutes_usage, ::Types::Ci::Minutes::NamespaceMonthlyUsageType.connection_type,
          null: true,
          description: 'Compute usage data for a namespace.' do
          argument :namespace_id, ::Types::GlobalIDType[::Namespace],
            required: false,
            description: 'Global ID of the Namespace for the monthly compute usage.'
          argument :date, ::Types::DateType,
            required: false,
            description: 'Date for which to retrieve the usage data, should be the first day of a month.'
        end
        field :current_license, ::Types::Admin::CloudLicenses::CurrentLicenseType,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::CurrentLicenseResolver,
          description: 'Fields related to the current license.'
        field :devops_adoption_enabled_namespaces,
          null: true,
          description: 'Get configured DevOps adoption namespaces. **Status:** Beta. This endpoint is subject to ' \
                       'change without notice.',
          resolver: ::Resolvers::Analytics::DevopsAdoption::EnabledNamespacesResolver
        field :epic_board_list, ::Types::Boards::EpicListType,
          null: true,
          resolver: ::Resolvers::Boards::EpicListResolver
        field :geo_node, ::Types::Geo::GeoNodeType,
          null: true,
          resolver: ::Resolvers::Geo::GeoNodeResolver,
          description: 'Find a Geo node.'
        field :iteration, ::Types::IterationType,
          null: true,
          description: 'Find an iteration.' do
          argument :id, ::Types::GlobalIDType[::Iteration],
            required: true,
            description: 'Find an iteration by its ID.'
        end
        field :instance_security_dashboard, ::Types::InstanceSecurityDashboardType,
          null: true,
          resolver: ::Resolvers::InstanceSecurityDashboardResolver,
          description: 'Fields related to Instance Security Dashboard.'
        field :license_history_entries, ::Types::Admin::CloudLicenses::LicenseHistoryEntryType.connection_type,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::LicenseHistoryEntriesResolver,
          description: 'Fields related to entries in the license history.'
        field :subscription_future_entries, ::Types::Admin::CloudLicenses::SubscriptionFutureEntryType.connection_type,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::SubscriptionFutureEntriesResolver,
          description: 'Fields related to entries in future subscriptions.'
        field :vulnerabilities,
          ::Types::VulnerabilityType.connection_type,
          null: true,
          extras: [:lookahead],
          description: "Vulnerabilities reported on projects on the current user's instance security dashboard.",
          resolver: ::Resolvers::VulnerabilitiesResolver
        field :vulnerabilities_count_by_day,
          ::Types::VulnerabilitiesCountByDayType.connection_type,
          null: true,
          resolver: ::Resolvers::VulnerabilitiesCountPerDayResolver,
          description: "The historical number of vulnerabilities per day for the projects on the current " \
                       "user's instance security dashboard."
        field :vulnerability,
          ::Types::VulnerabilityType,
          null: true,
          description: "Find a vulnerability." do
          argument :id, ::Types::GlobalIDType[::Vulnerability],
            required: true,
            description: 'Global ID of the Vulnerability.'
        end
        field :workspace, ::Types::RemoteDevelopment::WorkspaceType,
          null: true,
          description: 'Find a workspace.' do
          argument :id, ::Types::GlobalIDType[::RemoteDevelopment::Workspace],
            required: true,
            description: 'Find a workspace by its ID.'
        end
        field :workspaces,
          ::Types::RemoteDevelopment::WorkspaceType.connection_type,
          null: true,
          resolver: ::Resolvers::RemoteDevelopment::WorkspacesAdminResolver,
          description: 'Find workspaces across the entire instance. This field is only available to instance admins, ' \
                       'it will return an empty result for all non-admins.'
        field :instance_external_audit_event_destinations,
          ::Types::AuditEvents::InstanceExternalAuditEventDestinationType.connection_type,
          null: true,
          description: 'Instance level external audit event destinations.',
          resolver: ::Resolvers::AuditEvents::InstanceExternalAuditEventDestinationsResolver

        field :ai_conversation_threads, ::Types::Ai::Conversations::ThreadType.connection_type,
          resolver: ::Resolvers::Ai::Conversations::ThreadsResolver,
          experiment: { milestone: '17.9' },
          description: 'List conversation threads of AI features.'

        field :ai_messages, ::Types::Ai::MessageType.connection_type,
          resolver: ::Resolvers::Ai::ChatMessagesResolver,
          experiment: { milestone: '16.1' },
          description: 'Find GitLab Duo Chat messages.'

        field :duo_workflow_events, ::Types::Ai::DuoWorkflows::WorkflowEventType.connection_type,
          resolver: ::Resolvers::Ai::DuoWorkflows::WorkflowEventsResolver,
          experiment: { milestone: '17.2' },
          description: 'List the events for a Duo Workflow.'

        field :duo_workflow_workflows, ::Types::Ai::DuoWorkflows::WorkflowType.connection_type,
          resolver: ::Resolvers::Ai::DuoWorkflows::WorkflowsResolver,
          experiment: { milestone: '17.2' },
          description: 'List the workflows owned by the current user.'

        field :ci_queueing_history,
          ::Types::Ci::QueueingHistoryType,
          null: true,
          experiment: { milestone: '16.4' },
          description: 'Time taken for CI jobs to be picked up by runner by percentile. ' \
            'Enable the ClickHouse database backend to use this query.',
          resolver: ::Resolvers::Ci::InstanceQueueingHistoryResolver,
          extras: [:lookahead]
        field :runner_usage_by_project,
          [::Types::Ci::RunnerUsageByProjectType],
          null: true,
          description: 'Runner usage by project. Enable the ClickHouse database backend to use this query.',
          resolver: ::Resolvers::Ci::RunnerUsageByProjectResolver
        field :runner_usage,
          [::Types::Ci::RunnerUsageType],
          null: true,
          description: 'Runner usage by runner. Enable the ClickHouse database backend to use this query.',
          resolver: ::Resolvers::Ci::RunnerUsageResolver

        field :instance_google_cloud_logging_configurations,
          ::Types::AuditEvents::Instance::GoogleCloudLoggingConfigurationType.connection_type,
          null: true,
          description: 'Instance level google cloud logging configurations.',
          resolver: ::Resolvers::AuditEvents::Instance::GoogleCloudLoggingConfigurationsResolver
        field :member_role_permissions,
          ::Types::MemberRoles::CustomizablePermissionType.connection_type,
          null: true,
          description: 'List of all customizable permissions.',
          experiment: { milestone: '16.4' }
        field :member_role, ::Types::MemberRoles::MemberRoleType,
          null: true, description: 'Finds a single custom role for the instance. Available only for self-managed.',
          resolver: ::Resolvers::MemberRoles::RolesResolver.single,
          experiment: { milestone: '16.6' }
        field :standard_role, ::Types::Members::StandardRoleType,
          null: true, description: 'Finds a single default role for the instance. Available only for self-managed.',
          resolver: ::Resolvers::Members::StandardRolesResolver.single,
          experiment: { milestone: '17.6' }
        field :standard_roles, ::Types::Members::StandardRoleType.connection_type,
          null: true, description: 'Default roles available for the instance. Available only for self-managed.',
          resolver: ::Resolvers::Members::StandardRolesResolver,
          experiment: { milestone: '17.3' }
        field :self_managed_add_on_eligible_users,
          ::Types::GitlabSubscriptions::AddOnUserType.connection_type,
          null: true,
          description: 'Users within the self-managed instance who are eligible for add-ons.',
          resolver: ::Resolvers::GitlabSubscriptions::SelfManaged::AddOnEligibleUsersResolver,
          experiment: { milestone: '16.7' }
        field :self_managed_users_queued_for_role_promotion,
          EE::Types::GitlabSubscriptions::MemberManagement::UsersQueuedForRolePromotionType.connection_type,
          null: true,
          experiment: { milestone: '17.1' },
          resolver: ::Resolvers::GitlabSubscriptions::MemberManagement::SelfManaged::
              UsersQueuedForRolePromotionResolver,
          description: 'Fields related to users within a self-managed instance that are pending role ' \
                       'promotion approval.'
        field :audit_events_instance_amazon_s3_configurations,
          ::Types::AuditEvents::Instance::AmazonS3ConfigurationType.connection_type,
          null: true,
          description: 'Instance-level Amazon S3 configurations for audit events.',
          resolver: ::Resolvers::AuditEvents::Instance::AmazonS3ConfigurationsResolver
        field :member_roles, ::Types::MemberRoles::MemberRoleType.connection_type,
          null: true, description: 'Custom roles available for the instance. Available only for self-managed.',
          resolver: ::Resolvers::MemberRoles::RolesResolver,
          experiment: { milestone: '16.7' }
        field :google_cloud_artifact_registry_repository_artifact,
          ::Types::GoogleCloud::ArtifactRegistry::ArtifactDetailsType,
          null: true,
          description: 'Details about an artifact in the Google Artifact Registry.',
          resolver: ::Resolvers::GoogleCloud::ArtifactRegistry::ArtifactResolver,
          experiment: { milestone: '16.10' }
        field :audit_events_instance_streaming_destinations,
          ::Types::AuditEvents::Instance::StreamingDestinationType.connection_type,
          null: true,
          description: 'Instance-level external audit event streaming destinations.',
          resolver: ::Resolvers::AuditEvents::Instance::StreamingDestinationsResolver,
          experiment: { milestone: '16.11' }

        field :ai_self_hosted_models,
          ::Types::Ai::SelfHostedModels::SelfHostedModelType.connection_type,
          null: true,
          resolver: ::Resolvers::Ai::SelfHostedModels::SelfHostedModelsResolver,
          experiment: { milestone: '17.1' },
          description: 'Returns the self-hosted model if an ID is provided, otherwise returns all models.' do
            argument :id, ::Types::GlobalIDType[::Ai::SelfHostedModel],
              required: false,
              description: "Global ID of a self-hosted model."
          end

        field :cloud_connector_status,
          ::Types::CloudConnector::StatusType,
          null: true,
          description: 'Run a series of status checks for Cloud Connector features.',
          resolver: ::Resolvers::CloudConnector::StatusResolver,
          experiment: { milestone: '17.3' }

        field :project_secrets_manager, ::Types::SecretsManagement::ProjectSecretsManagerType,
          null: true,
          experiment: { milestone: '17.4' },
          description: 'Find a project secrets manager.',
          resolver: ::Resolvers::SecretsManagement::ProjectSecretsManagerResolver

        field :project_secrets, ::Types::SecretsManagement::ProjectSecretType.connection_type,
          null: true,
          experiment: { milestone: '17.8' },
          description: 'List project secrets.',
          resolver: ::Resolvers::SecretsManagement::ProjectSecretsResolver

        field :project_secret, ::Types::SecretsManagement::ProjectSecretType,
          null: true,
          experiment: { milestone: '17.9' },
          description: 'View a specific project secret.',
          resolver: ::Resolvers::SecretsManagement::ProjectSecretViewResolver

        field :ai_feature_settings,
          ::Types::Ai::FeatureSettings::FeatureSettingType.connection_type,
          null: true,
          description: 'List of configurable AI features.',
          resolver: ::Resolvers::Ai::FeatureSettings::FeatureSettingsResolver,
          experiment: { milestone: '17.4' }

        field :ai_slash_commands, [::Types::Ai::SlashCommandType], null: true,
          resolver: ::Resolvers::Ai::SlashCommandsResolver,
          description: 'Get available Duo Chat slash commands for the current user for a specific URL'

        field :compliance_requirement_controls, ::Types::ComplianceManagement::ComplianceRequirementControlType,
          null: true,
          fallback_value: [],
          description: 'Get the list of all the compliance requirement controls.'

        field :duo_settings, ::Types::Ai::DuoSettings::DuoSettingsType,
          null: true,
          fallback_value: {},
          description: 'Get GitLab Duo settings',
          resolver: ::Resolvers::Ai::DuoSettings::DuoSettingsResolver,
          experiment: { milestone: '17.9' }
      end

      def vulnerability(id:)
        ::GitlabSchema.find_by_gid(id)
      end

      def iteration(id:)
        ::GitlabSchema.find_by_gid(id)
      end

      def workspace(id:)
        unless License.feature_available?(:remote_development)
          # NOTE: Could have `included Gitlab::Graphql::Authorize::AuthorizeResource` and then use
          #       raise_resource_not_available_error!, but didn't want to take the risk to mix that into
          #       the root query type
          # rubocop:disable Graphql/ResourceNotAvailableError -- intentionally not used - see note above
          raise ::Gitlab::Graphql::Errors::ResourceNotAvailable,
            "'remote_development' licensed feature is not available"
          # rubocop:enable Graphql/ResourceNotAvailableError
        end

        ::GitlabSchema.find_by_gid(id)
      end

      def ci_minutes_usage(namespace_id: nil, date: nil)
        root_namespace = find_root_namespace(namespace_id)
        if date
          ::Ci::Minutes::NamespaceMonthlyUsage.by_namespace_and_date(root_namespace, date)
        else
          ::Ci::Minutes::NamespaceMonthlyUsage.for_namespace(root_namespace)
        end
      end

      def member_role_permissions
        MemberRole.all_customizable_permissions.keys.filter do |permission|
          ::MemberRole.permission_enabled?(permission, current_user)
        end
      end

      private

      def find_root_namespace(namespace_id)
        return current_user&.namespace unless namespace_id

        namespace = ::Gitlab::Graphql::Lazy.force(::GitlabSchema.find_by_gid(namespace_id))
        return unless namespace&.root?

        namespace
      end
    end
  end
end
