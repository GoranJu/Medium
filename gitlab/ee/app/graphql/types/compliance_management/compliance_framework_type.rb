# frozen_string_literal: true

# rubocop: disable Graphql/AuthorizeTypes -- because ComplianceFrameworkType is, and should only be, accessible via ProjectType

module Types
  module ComplianceManagement
    class ComplianceFrameworkType < Types::BaseObject
      graphql_name 'ComplianceFramework'
      description 'Represents a ComplianceFramework associated with a Project'

      field :id, GraphQL::Types::ID,
        null: false,
        description: 'Compliance framework ID.'

      field :name, GraphQL::Types::String,
        null: false,
        description: 'Name of the compliance framework.'

      field :description, GraphQL::Types::String,
        null: false,
        description: 'Description of the compliance framework.'

      field :color, GraphQL::Types::String,
        null: false,
        description: 'Hexadecimal representation of compliance framework\'s label color.'

      field :default, GraphQL::Types::Boolean,
        null: true, description: 'Default compliance framework for the group.'

      field :pipeline_configuration_full_path, GraphQL::Types::String,
        null: true,
        description: 'Full path of the compliance pipeline configuration stored in a project repository, such as `.gitlab/.compliance-gitlab-ci.yml@compliance/hipaa`. Ultimate only.',
        deprecated: { reason: 'Use pipeline execution policies instead', milestone: '17.4' },
        authorize: :admin_compliance_pipeline_configuration

      field :projects, Types::ProjectType.connection_type,
        null: true,
        description: 'Projects associated with the compliance framework.'

      field :scan_execution_policies,
        ::Types::SecurityOrchestration::ScanExecutionPolicyType.connection_type,
        calls_gitaly: true,
        null: true,
        description: 'Scan Execution Policies of the compliance framework.',
        resolver: ::Resolvers::ComplianceManagement::SecurityPolicies::ScanExecutionPolicyResolver

      field :scan_result_policies, # TODO: Rename this to merge request approval policies
        ::Types::SecurityOrchestration::ScanResultPolicyType.connection_type,
        calls_gitaly: true,
        null: true,
        description: 'Scan Result Policies of the compliance framework.',
        resolver: ::Resolvers::ComplianceManagement::SecurityPolicies::ScanResultPolicyResolver

      field :pipeline_execution_policies,
        ::Types::SecurityOrchestration::PipelineExecutionPolicyType.connection_type,
        calls_gitaly: true,
        null: true,
        description: 'Pipeline Execution Policies of the compliance framework.',
        resolver: ::Resolvers::ComplianceManagement::SecurityPolicies::PipelineExecutionPolicyResolver

      field :compliance_requirements,
        ::Types::ComplianceManagement::ComplianceRequirementType.connection_type,
        null: true,
        description: 'Compliance requirements of the compliance framework.'

      field :vulnerability_management_policies,
        ::Types::Security::VulnerabilityManagementPolicyType.connection_type,
        calls_gitaly: true,
        null: true,
        description: 'Vulnerability Management Policies of the compliance framework.',
        resolver: ::Resolvers::ComplianceManagement::SecurityPolicies::VulnerabilityManagementPolicyResolver

      def default
        object.id == object.namespace.namespace_settings.default_compliance_framework_id
      end
    end
  end
end
# rubocop: enable Graphql/AuthorizeTypes
