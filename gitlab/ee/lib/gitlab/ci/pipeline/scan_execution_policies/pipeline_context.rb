# frozen_string_literal: true

# This class encapsulates functionality related to Scan Execution Policies and is used during pipeline creation.
module Gitlab
  module Ci
    module Pipeline
      module ScanExecutionPolicies
        class PipelineContext
          include ::Gitlab::Utils::StrongMemoize

          def initialize(project:, ref:, current_user:, source:)
            @project = project
            @ref = ref
            @current_user = current_user
            @source = source
          end

          def has_scan_execution_policies?
            apply_scan_execution_policies? && policies.present?
          end

          def active_scan_execution_actions
            policies.flat_map(&:actions).compact.uniq
          end
          strong_memoize_attr :active_scan_execution_actions

          def skip_ci_allowed?
            return true unless has_scan_execution_policies?

            policies.all? { |policy| policy.skip_ci_allowed?(current_user&.id) }
          end

          private

          attr_reader :project, :ref, :current_user, :source

          def apply_scan_execution_policies?
            return false unless project&.feature_available?(:security_orchestration_policies)
            return false unless Enums::Ci::Pipeline.ci_sources.key?(source&.to_sym)

            # TODO: Uncomment this after https://gitlab.com/gitlab-org/gitlab/-/issues/515866 is fixed
            # project.security_policies.type_scan_execution_policy.exists?
            true
          end

          def policies
            return [] if valid_security_orchestration_policy_configurations.blank?

            policies = valid_security_orchestration_policy_configurations
              .flat_map do |configuration|
              configuration.active_pipeline_policies_for_project(ref, project)
            end.compact

            policies.map do |policy|
              ::Security::ScanExecutionPolicy::Config.new(policy: policy)
            end
          end
          strong_memoize_attr :policies

          def valid_security_orchestration_policy_configurations
            @valid_security_orchestration_policy_configurations ||=
              ::Gitlab::Security::Orchestration::ProjectPolicyConfigurations.new(project).all
          end
        end
      end
    end
  end
end
