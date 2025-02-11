# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Variables
        module Builder
          extend ::Gitlab::Utils::Override

          override :initialize
          def initialize(pipeline)
            super

            @scan_execution_policies_variables_builder =
              ::Gitlab::Ci::Variables::Builder::ScanExecutionPolicies.new(pipeline)
          end

          override :scoped_variables_for_pipeline_seed
          def scoped_variables_for_pipeline_seed(job_attr, environment:, kubernetes_namespace:, user:, trigger_request:)
            variables = super.tap do |variables|
              variables.concat(scan_execution_policies_variables_builder.variables(job_attr[:name]))
            end

            replace_pipeline_execution_policy_variables(variables, job_attr[:options], job_attr[:yaml_variables])
          end

          # When adding new variables, consider either adding or commenting out them in the following methods:
          # - unprotected_scoped_variables
          # - scoped_variables_for_pipeline_seed
          override :scoped_variables
          def scoped_variables(job, environment:, dependencies:)
            variables = super.tap do |variables|
              variables.concat(scan_execution_policies_variables_builder.variables(job.name))
            end

            # Reapply the PEP job YAML variables at the end to enforce the highest precedence
            replace_pipeline_execution_policy_variables(variables, job.options, job.yaml_variables)
          end

          private

          attr_reader :scan_execution_policies_variables_builder

          def replace_pipeline_execution_policy_variables(variables, options, yaml_variables)
            return variables unless !!options&.dig(:execution_policy_job)

            yaml_variable_keys = yaml_variables.pluck(:key).to_set # rubocop: disable CodeReuse/ActiveRecord -- this is not a DB query
            variables.reject { |var| yaml_variable_keys.include?(var.key) }.concat(yaml_variables)
          end
        end
      end
    end
  end
end
