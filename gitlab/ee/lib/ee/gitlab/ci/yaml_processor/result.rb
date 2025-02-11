# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module YamlProcessor
        module Result
          extend ::Gitlab::Utils::Override

          private

          override :build_attributes
          def build_attributes(name)
            job = jobs.fetch(name.to_sym, {})

            super.deep_merge(
              {
                options: {
                  dast_configuration: job[:dast_configuration],
                  identity: job[:identity],
                  execution_policy_job: execution_policy_job_option
                }.compact,
                secrets: job[:secrets]
              }.compact
            )
          end

          def execution_policy_job_option
            ci_config&.pipeline_policy_context&.creating_policy_pipeline? || nil
          end
        end
      end
    end
  end
end
