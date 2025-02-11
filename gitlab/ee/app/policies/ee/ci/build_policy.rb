# frozen_string_literal: true

module EE
  module Ci
    module BuildPolicy
      extend ActiveSupport::Concern

      prepended do
        include TroubleshootJobPolicyHelper

        rule do
          can?(:read_build_trace) &
            troubleshoot_job_licensed &
            troubleshoot_job_cloud_connector_authorized &
            troubleshoot_job_with_ai_authorized
        end.enable(:troubleshoot_job_with_ai)
      end
    end
  end
end
