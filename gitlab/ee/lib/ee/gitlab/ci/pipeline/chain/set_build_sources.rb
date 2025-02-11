# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module SetBuildSources
            extend ::Gitlab::Utils::Override

            override :pipeline_execution_policy_build?
            def pipeline_execution_policy_build?(build)
              build.options&.dig(:execution_policy_job)
            end

            override :scan_execution_policy_build?
            def scan_execution_policy_build?(build)
              scan_types = ::Security::ScanExecutionPolicy::PIPELINE_SCAN_TYPES
                .map(&:dasherize).join('|')
              build.name.match("^(#{scan_types})-\\d+$")
            end
          end
        end
      end
    end
  end
end
